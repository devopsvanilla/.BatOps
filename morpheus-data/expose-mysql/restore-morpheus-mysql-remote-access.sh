#!/usr/bin/env bash
# ==============================================================================
# Script: restore-morpheus-mysql-remote-access.sh
# Descrição: Restaura as configurações originais do Morpheus Data / Percona e do
#            firewall, revertendo a liberação de acesso remoto e o usuário criado.
#            Compatível com Single-Node Appliance e Three-Node HA (Percona).
#            Gera também backup de segurança do estado atual pré-restauração.
# ==============================================================================
set -euo pipefail

# Constantes e valores padrão
readonly DEFAULT_BACKUP_BASE_DIR="/var/opt/morpheus/backups/mysql-remote-access"
readonly DEFAULT_MORPHEUS_CONFIG="/etc/morpheus/morpheus.rb"
readonly DEFAULT_SECRETS_FILE="/etc/morpheus/morpheus-secrets.json"
readonly DEFAULT_PORT="3306"

# Variáveis configuráveis
backup_base_dir="${DEFAULT_BACKUP_BASE_DIR}"
target_backup_dir=""
morpheus_config="${DEFAULT_MORPHEUS_CONFIG}"
db_admin_password=""
keep_db_user=false
skip_reconfigure=false

# ------------------------------------------------------------------------------
# Função de Ajuda (--help)
# ------------------------------------------------------------------------------
usage() {
    cat <<EOF
Uso: $(basename "$0") [OPÇÕES]

Restaura a configuração anterior do Morpheus e do firewall, revertendo a liberação
de acesso remoto ao MySQL/Percona. Compatível com Single-Node e Three-Node HA.

OPÇÕES:
  -b, --backup-dir <DIR>        Caminho do diretório de backup a ser restaurado.
                                Se omitido, busca o link 'latest' ou o mais recente em '${DEFAULT_BACKUP_BASE_DIR}'.
      --keep-db-user            Mantém o usuário criado no MySQL (não executa DROP USER).
      --skip-reconfigure        Não executa 'morpheus-ctl reconfigure' (apenas modo Appliance morpheus.rb).
  -R, --root-password <SENHA>   Senha de root/admin do MySQL (opcional, tenta detecção automática).
  -c, --config <ARQUIVO>        Caminho do arquivo morpheus.rb (padrão: ${DEFAULT_MORPHEUS_CONFIG}).
  -h, --help                    Exibe esta mensagem de ajuda e encerra.

EXEMPLOS:
  sudo $(basename "$0")
  sudo $(basename "$0") --backup-dir /var/opt/morpheus/backups/mysql-remote-access/backup-20260910_120000
  sudo $(basename "$0") --keep-db-user
EOF
}

# ------------------------------------------------------------------------------
# Funções de Log
# ------------------------------------------------------------------------------
log_info() {
    echo -e "\033[1;34m[INFO]\033[0m $*"
}

log_ok() {
    echo -e "\033[1;32m[OK]\033[0m $*"
}

log_warn() {
    echo -e "\033[1;33m[AVISO]\033[0m $*" >&2
}

log_error() {
    echo -e "\033[1;31m[ERRO]\033[0m $*" >&2
}

# ------------------------------------------------------------------------------
# Verificação de Permissões de Root
# ------------------------------------------------------------------------------
check_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        log_error "Este script requer privilégios de superusuário (root)."
        log_error "Execute novamente com 'sudo $0' ou como usuário root."
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Localização de Binários e Dependências
# ------------------------------------------------------------------------------
find_mysql_bin() {
    local candidates=(
        "/usr/bin/mysql"
        "/opt/morpheus-node/embedded/bin/mysql"
        "/opt/morpheus/embedded/bin/mysql"
        "/usr/local/bin/mysql"
    )

    for candidate in "${candidates[@]}"; do
        if [[ -x "${candidate}" ]]; then
            echo "${candidate}"
            return 0
        fi
    done

    if command -v mysql >/dev/null 2>&1; then
        command -v mysql
        return 0
    fi

    echo ""
}

find_mysql_socket() {
    local sockets=(
        "/var/run/morpheus/mysqld/mysqld.sock"
        "/var/run/morpheus/mysql/mysql.sock"
        "/run/morpheus/mysqld/mysqld.sock"
        "/run/morpheus/mysql/mysql.sock"
        "/var/opt/morpheus/mysql/mysql.sock"
        "/var/opt/morpheus/mysql/mysqld.sock"
        "/var/opt/morpheus/mysql/data/mysql.sock"
        "/var/opt/morpheus/percona/percona.sock"
        "/var/opt/morpheus/percona/mysql.sock"
        "/var/opt/morpheus/percona/data/mysql.sock"
        "/var/run/mysqld/mysqld.sock"
        "/run/mysqld/mysqld.sock"
        "/var/run/percona/mysql.sock"
        "/var/run/percona-xtradb-cluster/mysqld.sock"
        "/var/lib/mysql/mysql.sock"
        "/tmp/mysql.sock"
        "/var/tmp/mysql.sock"
    )
    for s in "${sockets[@]}"; do
        if [[ -S "${s}" ]]; then
            echo "${s}"
            return 0
        fi
    done

    if command -v ss >/dev/null 2>&1; then
        local ss_sock
        ss_sock=$(ss -xlp 2>/dev/null | grep -E "mysqld|percona" | grep -oP '/\S+\.sock' | head -n1 || true)
        if [[ -n "${ss_sock}" && -S "${ss_sock}" ]]; then
            echo "${ss_sock}"
            return 0
        fi
    fi

    if command -v lsof >/dev/null 2>&1; then
        local lsof_sock
        lsof_sock=$(lsof -c mysqld -a -U 2>/dev/null | grep -oP '/\S+\.sock' | head -n1 || true)
        if [[ -n "${lsof_sock}" && -S "${lsof_sock}" ]]; then
            echo "${lsof_sock}"
            return 0
        fi
    fi

    local find_sock
    find_sock=$(find /var/opt/morpheus /var/run /run /tmp /var/lib -maxdepth 3 -type s \( -name "*mysql*.sock" -o -name "*percona*.sock" \) 2>/dev/null | head -n1 || true)
    if [[ -n "${find_sock}" && -S "${find_sock}" ]]; then
        echo "${find_sock}"
        return 0
    fi

    echo ""
}

# ------------------------------------------------------------------------------
# Teste de Autenticação com Fallback Socket / TCP 127.0.0.1
# ------------------------------------------------------------------------------
test_mysql_auth() {
    local bin="$1"
    local sock="$2"
    local user="$3"
    local pass="$4"

    if [[ -n "${sock}" && -S "${sock}" ]]; then
        local cmd_sock=("${bin}" "-u" "${user}")
        if [[ -n "${pass}" ]]; then
            cmd_sock+=("-p${pass}")
        fi
        cmd_sock+=("-S" "${sock}" "--batch" "-e" "SELECT 1;")
        if "${cmd_sock[@]}" >/dev/null 2>&1; then
            return 0
        fi
    fi

    local cmd_tcp=("${bin}" "-u" "${user}")
    if [[ -n "${pass}" ]]; then
        cmd_tcp+=("-p${pass}")
    fi
    cmd_tcp+=("-h" "127.0.0.1" "-P" "${DEFAULT_PORT}" "--batch" "-e" "SELECT 1;")
    if "${cmd_tcp[@]}" >/dev/null 2>&1; then
        return 0
    fi

    local cmd_proto=("${bin}" "-u" "${user}")
    if [[ -n "${pass}" ]]; then
        cmd_proto+=("-p${pass}")
    fi
    cmd_proto+=("-h" "localhost" "--protocol=TCP" "-P" "${DEFAULT_PORT}" "--batch" "-e" "SELECT 1;")
    if "${cmd_proto[@]}" >/dev/null 2>&1; then
        return 0
    fi

    local cmd_def=("${bin}" "-u" "${user}")
    if [[ -n "${pass}" ]]; then
        cmd_def+=("-p${pass}")
    fi
    cmd_def+=("--batch" "-e" "SELECT 1;")
    if "${cmd_def[@]}" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

# ------------------------------------------------------------------------------
# Obtenção de Credenciais Administrativas do MySQL/Percona
# ------------------------------------------------------------------------------
get_mysql_admin_auth() {
    local mysql_bin="$1"
    local socket="$2"
    local provided_pwd="$3"

    if [[ -n "${provided_pwd}" ]]; then
        if test_mysql_auth "${mysql_bin}" "${socket}" "root" "${provided_pwd}"; then
            echo "${provided_pwd}"
            return 0
        fi
    fi

    if test_mysql_auth "${mysql_bin}" "${socket}" "root" ""; then
        echo ""
        return 0
    fi

    local secrets_candidates=(
        "${DEFAULT_SECRETS_FILE}"
        "/var/opt/morpheus/morpheus-secrets.json"
        "/var/opt/morpheus/package-secrets.json"
        "/etc/morpheus/package-secrets.json"
    )

    for sf in "${secrets_candidates[@]}"; do
        if [[ -f "${sf}" ]]; then
            local discovered_passwords=()
            if command -v python3 >/dev/null 2>&1; then
                while IFS= read -r pwd_entry; do
                    if [[ -n "${pwd_entry}" ]]; then
                        discovered_passwords+=("${pwd_entry}")
                    fi
                done < <(python3 -c "
import json
try:
    with open('${sf}') as f:
        d = json.load(f)
    keys_to_check = []
    for sec in ['percona', 'percona_cluster', 'percona_xtradb_cluster', 'pxc', 'mysql']:
        if sec in d and isinstance(d[sec], dict):
            for k in ['root_password', 'admin_password', 'password', 'cluster_password', 'morpheus_password', 'ops_password']:
                v = d[sec].get(k)
                if v and v not in keys_to_check:
                    keys_to_check.append(v)
    for k in ['percona_root_password', 'mysql_root_password', 'root_password', 'admin_password', 'db_root_password', 'morpheus_password']:
        v = d.get(k)
        if v and v not in keys_to_check:
            keys_to_check.append(v)
    for p in keys_to_check:
        print(p)
except Exception:
    pass
" 2>/dev/null || true)
            fi

            if [[ ${#discovered_passwords[@]} -eq 0 ]]; then
                while IFS= read -r pwd_entry; do
                    if [[ -n "${pwd_entry}" ]]; then
                        discovered_passwords+=("${pwd_entry}")
                    fi
                done < <(grep -E '"(root_password|admin_password|percona_password|morpheus_password|ops_password)"\s*:' "${sf}" 2>/dev/null | awk -F'"' '{print $4}' | grep -v '^$' || true)
            fi

            for candidate_pwd in "${discovered_passwords[@]}"; do
                if test_mysql_auth "${mysql_bin}" "${socket}" "root" "${candidate_pwd}"; then
                    echo "${candidate_pwd}"
                    return 0
                fi
            done

            for candidate_pwd in "${discovered_passwords[@]}"; do
                if test_mysql_auth "${mysql_bin}" "${socket}" "morpheus" "${candidate_pwd}"; then
                    echo "__USER__:morpheus:${candidate_pwd}"
                    return 0
                fi
            done
        fi
    done

    if [[ -f "${morpheus_config}" ]]; then
        local rb_passwords=()
        while IFS= read -r pwd_entry; do
            if [[ -n "${pwd_entry}" ]]; then
                rb_passwords+=("${pwd_entry}")
            fi
        done < <(grep -E "^\s*(percona|mysql|database)(\[[^]]*\])?\s*\[\s*['\"](root_password|admin_password|password|morpheus_password)['\"]\s*\]\s*=" "${morpheus_config}" 2>/dev/null | awk -F'=' '{print $2}' | tr -d " '\";" || true)

        for candidate_pwd in "${rb_passwords[@]}"; do
            if test_mysql_auth "${mysql_bin}" "${socket}" "root" "${candidate_pwd}"; then
                echo "${candidate_pwd}"
                return 0
            fi
            if test_mysql_auth "${mysql_bin}" "${socket}" "morpheus" "${candidate_pwd}"; then
                echo "__USER__:morpheus:${candidate_pwd}"
                return 0
            fi
        done
    fi

    if [[ -f "/root/.my.cnf" ]]; then
        local cnf_pwd
        cnf_pwd=$(grep -E "^\s*password\s*=" /root/.my.cnf 2>/dev/null | head -n1 | cut -d'=' -f2- | tr -d ' "' || true)
        if [[ -n "${cnf_pwd}" ]] && test_mysql_auth "${mysql_bin}" "${socket}" "root" "${cnf_pwd}"; then
            echo "${cnf_pwd}"
            return 0
        fi
    fi

    if [[ -f "/etc/mysql/debian.cnf" ]]; then
        local deb_pwd
        deb_pwd=$(grep -E "^\s*password\s*=" /etc/mysql/debian.cnf 2>/dev/null | head -n1 | cut -d'=' -f2- | tr -d ' "' || true)
        local deb_user
        deb_user=$(grep -E "^\s*user\s*=" /etc/mysql/debian.cnf 2>/dev/null | head -n1 | cut -d'=' -f2- | tr -d ' "' || true)
        if [[ -n "${deb_pwd}" && -n "${deb_user}" ]] && test_mysql_auth "${mysql_bin}" "${socket}" "${deb_user}" "${deb_pwd}"; then
            echo "__USER__:${deb_user}:${deb_pwd}"
            return 0
        fi
    fi

    local node_conf_candidates=(
        "/opt/morpheus-node/conf/config.yml"
        "/opt/morpheus-node/conf/config.yaml"
        "/etc/morpheus/morpheus-node.conf"
    )
    for cf in "${node_conf_candidates[@]}"; do
        if [[ -f "${cf}" ]]; then
            local node_passwords=()
            while IFS= read -r pwd_entry; do
                if [[ -n "${pwd_entry}" ]]; then
                    node_passwords+=("${pwd_entry}")
                fi
            done < <(grep -iE "(mysql|percona|password|root)" "${cf}" 2>/dev/null | grep -iE "password|pwd" | awk -F'[:=]' '{print $2}' | tr -d " '\";" || true)

            for candidate_pwd in "${node_passwords[@]}"; do
                if test_mysql_auth "${mysql_bin}" "${socket}" "root" "${candidate_pwd}"; then
                    echo "${candidate_pwd}"
                    return 0
                fi
            done
        fi
    done

    if [[ -t 0 ]]; then
        echo -n "Informe a senha do usuário root/admin do MySQL/Percona: " >&2
        local prompt_pwd
        read -rs prompt_pwd
        echo "" >&2
        echo "${prompt_pwd}"
        return 0
    fi

    echo ""
}

run_mysql_admin() {
    local mysql_bin="$1"
    local socket="$2"
    local admin_auth="$3"
    local sql="$4"

    local admin_user="root"
    local admin_pwd="${admin_auth}"

    if [[ "${admin_auth}" =~ ^__USER__:(.*):(.*)$ ]]; then
        admin_user="${BASH_REMATCH[1]}"
        admin_pwd="${BASH_REMATCH[2]}"
    fi

    local cmd=("${mysql_bin}" "-u" "${admin_user}")
    if [[ -n "${admin_pwd}" ]]; then
        cmd+=("-p${admin_pwd}")
    fi

    if [[ -n "${socket}" && -S "${socket}" ]]; then
        cmd+=("-S" "${socket}")
    else
        cmd+=("-h" "127.0.0.1" "-P" "${DEFAULT_PORT}")
    fi

    cmd+=("--batch" "--skip-column-names" "-e" "${sql}")

    "${cmd[@]}"
}

# ------------------------------------------------------------------------------
# Detecção do Gerenciador de Firewall
# ------------------------------------------------------------------------------
detect_firewall_backend() {
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet firewalld 2>/dev/null; then
            echo "firewalld"
            return 0
        fi
        if systemctl is-active --quiet ufw 2>/dev/null; then
            echo "ufw"
            return 0
        fi
    fi

    if command -v iptables >/dev/null 2>&1; then
        echo "iptables"
        return 0
    fi

    echo "none"
}

# ------------------------------------------------------------------------------
# Resolução do Diretório de Backup
# ------------------------------------------------------------------------------
resolve_backup_dir() {
    local requested_dir="$1"

    if [[ -n "${requested_dir}" ]]; then
        if [[ -d "${requested_dir}" ]]; then
            echo "${requested_dir}"
            return 0
        else
            log_error "Diretório de backup informado '${requested_dir}' não existe."
            exit 1
        fi
    fi

    local latest_symlink="${backup_base_dir}/latest"
    if [[ -L "${latest_symlink}" && -d "${latest_symlink}" ]]; then
        readlink -f "${latest_symlink}"
        return 0
    fi

    if [[ -d "${backup_base_dir}" ]]; then
        local most_recent
        most_recent=$(find "${backup_base_dir}" -maxdepth 1 -type d -name "backup-*" | sort -r | head -n1 || true)
        if [[ -n "${most_recent}" && -d "${most_recent}" ]]; then
            echo "${most_recent}"
            return 0
        fi
    fi

    log_error "Nenhum backup encontrado em '${backup_base_dir}'. Especifique com --backup-dir <DIR>."
    exit 1
}

# ------------------------------------------------------------------------------
# Criação de Backup de Segurança Pré-Restauração
# ------------------------------------------------------------------------------
create_pre_restore_safety_backup() {
    local safety_dir="$1"
    local fw_backend="$2"

    log_info "Criando backup de segurança pré-restauração em: ${safety_dir}"
    mkdir -p "${safety_dir}"

    if [[ -f "${morpheus_config}" ]]; then
        cp -p "${morpheus_config}" "${safety_dir}/morpheus.rb.current.bak"
    fi

    if [[ -f "/etc/morpheus/morpheus-node.conf" ]]; then
        cp -p "/etc/morpheus/morpheus-node.conf" "${safety_dir}/morpheus-node.conf.current.bak"
    fi

    if [[ "${fw_backend}" == "firewalld" ]]; then
        firewall-cmd --list-all >"${safety_dir}/firewalld-pre-restore.txt" 2>&1 || true
    elif [[ "${fw_backend}" == "ufw" ]]; then
        ufw status verbose >"${safety_dir}/ufw-pre-restore.txt" 2>&1 || true
    elif [[ "${fw_backend}" == "iptables" ]]; then
        iptables-save >"${safety_dir}/iptables-pre-restore.rules" 2>&1 || true
    fi

    log_ok "Backup de segurança pré-restauração gerado."
}

# ------------------------------------------------------------------------------
# Reversão das Regras de Firewall
# ------------------------------------------------------------------------------
revert_firewall_rule() {
    local fw_backend="$1"
    local subnet="$2"

    if [[ -z "${subnet}" ]]; then
        log_warn "Sub-rede não identificada nos metadados. Nenhuma regra de firewall específica pôde ser removida."
        return 0
    fi

    case "${fw_backend}" in
        firewalld)
            log_info "Removendo rich rule do firewalld para a sub-rede '${subnet}' na porta ${DEFAULT_PORT}/tcp..."
            firewall-cmd --permanent --remove-rich-rule="rule family='ipv4' source address='${subnet}' port port='${DEFAULT_PORT}' protocol='tcp' accept" 2>/dev/null || true
            firewall-cmd --reload 2>/dev/null || true
            log_ok "Regra no firewalld removida."
            ;;
        ufw)
            log_info "Removendo regra de liberação da sub-rede '${subnet}' no ufw..."
            ufw delete allow from "${subnet}" to any port "${DEFAULT_PORT}" proto tcp 2>/dev/null || true
            log_ok "Regra no ufw removida."
            ;;
        iptables)
            log_info "Removendo regra do iptables para a sub-rede '${subnet}'..."
            iptables -D INPUT -p tcp -s "${subnet}" --dport "${DEFAULT_PORT}" -j ACCEPT 2>/dev/null || true
            log_ok "Regra no iptables removida."
            ;;
        *)
            log_info "Nenhuma ação de firewall necessária."
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Remoção do Usuário Remoto no MySQL
# ------------------------------------------------------------------------------
remove_mysql_user() {
    local mysql_bin="$1"
    local socket="$2"
    local admin_auth="$3"
    local user="$4"
    local pattern="$5"

    if [[ -z "${mysql_bin}" || -z "${user}" || -z "${pattern}" ]]; then
        log_warn "Cliente MySQL ou dados de usuário ausentes. Pulando remoção automática no MySQL."
        return 0
    fi

    log_info "Removendo usuário MySQL '${user}'@'${pattern}'..."
    local sql="
DROP USER IF EXISTS '${user}'@'${pattern}';
FLUSH PRIVILEGES;
"
    run_mysql_admin "${mysql_bin}" "${socket}" "${admin_auth}" "${sql}" 2>/dev/null || true
    log_ok "Usuário '${user}'@'${pattern}' removido do MySQL."
}

# ------------------------------------------------------------------------------
# Função Principal (main)
# ------------------------------------------------------------------------------
main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b | --backup-dir)
                target_backup_dir="${2:-}"
                shift 2
                ;;
            -R | --root-password)
                db_admin_password="${2:-}"
                shift 2
                ;;
            --keep-db-user)
                keep_db_user=true
                shift
                ;;
            --skip-reconfigure)
                skip_reconfigure=true
                shift
                ;;
            -c | --config)
                morpheus_config="${2:-}"
                shift 2
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            *)
                log_error "Opção inválida: $1"
                usage >&2
                exit 1
                ;;
        esac
    done

    check_root

    log_info "Iniciando processo de restauração das configurações do MySQL/Percona..."

    local selected_backup
    selected_backup="$(resolve_backup_dir "${target_backup_dir}")"
    log_ok "Backup de origem selecionado: ${selected_backup}"

    # Leitura de metadados
    local meta_file="${selected_backup}/backup-metadata.env"
    local node_mode="unknown"
    local db_user="morpheus_remote"
    local subnet=""
    local mysql_host_pattern=""
    local fw_meta_backend=""
    local meta_mysql_config=""
    local meta_mysql_modified="false"
    local meta_dropin="false"

    if [[ -f "${meta_file}" ]]; then
        log_info "Carregando metadados do arquivo: ${meta_file}"
        # shellcheck disable=SC1090
        source "${meta_file}"
        node_mode="${NODE_MODE:-appliance}"
        db_user="${DB_USER:-${db_user}}"
        subnet="${SUBNET:-}"
        mysql_host_pattern="${MYSQL_HOST_PATTERN:-}"
        fw_meta_backend="${FIREWALL_BACKEND:-}"
        meta_mysql_config="${MYSQL_CONFIG_FILE:-}"
        meta_mysql_modified="${MYSQL_CONFIG_MODIFIED:-false}"
        meta_dropin="${IS_DROPIN_CONFIG:-false}"
    fi

    local current_fw_backend
    current_fw_backend="$(detect_firewall_backend)"
    local effective_fw="${fw_meta_backend:-${current_fw_backend}}"

    # 1. Backup de segurança pré-restauração
    local safety_timestamp
    safety_timestamp="$(date +"%Y%m%d_%H%M%S")"
    local safety_backup_dir="${backup_base_dir}/pre-restore-${safety_timestamp}"
    create_pre_restore_safety_backup "${safety_backup_dir}" "${current_fw_backend}"

    # 2. Restauração das configurações de banco
    if [[ "${node_mode}" == "appliance" ]]; then
        local morpheus_bak="${selected_backup}/morpheus.rb.bak"
        if [[ -f "${morpheus_bak}" ]]; then
            log_info "Restaurando '${morpheus_config}' a partir de '${morpheus_bak}'..."
            cp -p "${morpheus_bak}" "${morpheus_config}"
            log_ok "Arquivo '${morpheus_config}' restaurado com sucesso."
        fi

        if [[ "${skip_reconfigure}" == false ]]; then
            log_info "Executando 'morpheus-ctl reconfigure'..."
            if command -v morpheus-ctl >/dev/null 2>&1; then
                morpheus-ctl reconfigure
            elif [[ -x "/usr/bin/morpheus-ctl" ]]; then
                /usr/bin/morpheus-ctl reconfigure
            fi
            log_ok "Reconfiguração do Morpheus finalizada."
        fi
    elif [[ "${node_mode}" == "percona_node" ]]; then
        if [[ "${meta_mysql_modified}" == "true" ]]; then
            if [[ "${meta_dropin}" == "true" && -n "${meta_mysql_config}" && -f "${meta_mysql_config}" ]]; then
                log_info "Removendo arquivo drop-in de configuração '${meta_mysql_config}'..."
                rm -f "${meta_mysql_config}"
                log_ok "Arquivo drop-in removido."
            elif [[ -f "${selected_backup}/mysql-config.bak" && -n "${meta_mysql_config}" ]]; then
                log_info "Restaurando '${meta_mysql_config}' a partir do backup..."
                cp -p "${selected_backup}/mysql-config.bak" "${meta_mysql_config}"
                log_ok "Configuração do MySQL restaurada."
            fi

            log_info "Reiniciando serviço MySQL/Percona..."
            systemctl restart mysql 2>/dev/null || systemctl restart mysqld 2>/dev/null || systemctl restart percona-xtradb-cluster 2>/dev/null || true
            log_ok "Serviço MySQL reiniciado."
        else
            log_ok "A configuração do MySQL não havia sido alterada durante a ativação."
        fi
    fi

    # 3. Reversão de firewall
    revert_firewall_rule "${effective_fw}" "${subnet}"

    # 4. Remoção de usuário MySQL
    if [[ "${keep_db_user}" == false ]]; then
        local mysql_bin
        mysql_bin="$(find_mysql_bin)"
        local mysql_socket
        mysql_socket="$(find_mysql_socket)"

        if [[ -n "${mysql_bin}" && -n "${mysql_host_pattern}" ]]; then
            local admin_auth
            admin_auth="$(get_mysql_admin_auth "${mysql_bin}" "${mysql_socket}" "${db_admin_password}")"
            remove_mysql_user "${mysql_bin}" "${mysql_socket}" "${admin_auth}" "${db_user}" "${mysql_host_pattern}"
        fi
    else
        log_info "Opção --keep-db-user ativa. Usuário MySQL mantido."
    fi

    cat <<EOF

==============================================================================
                    RESTAURAÇÃO CONCLUÍDA COM SUCESSO
==============================================================================

  • Topologia                       : $(if [[ "${node_mode}" == "percona_node" ]]; then echo "Three-Node HA (Percona Cluster)"; else echo "Appliance Single-Node"; fi)
  • Backup restaurado               : ${selected_backup}
  • Backup de segurança prévio gerado: ${safety_backup_dir}
  • Configuração de Banco           : Restaurada para o estado anterior
  • Regras de Firewall               : Revertidas (porta ${DEFAULT_PORT}/tcp fechada para ${subnet:-'sub-rede configurada'})
  • Usuário MySQL (${db_user})      : $(if [[ "${keep_db_user}" == true ]]; then echo "Mantido (--keep-db-user)"; else echo "Removido (DROP USER)"; fi)

==============================================================================

EOF
}

main "$@"
