#!/usr/bin/env bash
# ==============================================================================
# Script: configure-morpheus-mysql-remote-access.sh
# Descrição: Habilita o acesso remoto ao MySQL/Percona do HPE Morpheus Data
#            Enterprise, suportando topologias Single-Node (morpheus.rb) e
#            Three-Node HA (Percona XtraDB Cluster / morpheus-node).
#            Gera backup prévio das configurações, abre regras de firewall no
#            SO, concede permissões ao usuário no banco e valida a conexão.
# ==============================================================================
set -euo pipefail

# Constantes e valores padrão
readonly DEFAULT_BACKUP_BASE_DIR="/var/opt/morpheus/backups/mysql-remote-access"
readonly DEFAULT_MORPHEUS_CONFIG="/etc/morpheus/morpheus.rb"
readonly DEFAULT_SECRETS_FILE="/etc/morpheus/morpheus-secrets.json"
readonly DEFAULT_DB_NAME="morpheus"
readonly DEFAULT_DB_USER="morpheus_remote"
readonly DEFAULT_PORT="3306"

# Variáveis configuráveis
backup_base_dir="${DEFAULT_BACKUP_BASE_DIR}"
morpheus_config="${DEFAULT_MORPHEUS_CONFIG}"
db_name="${DEFAULT_DB_NAME}"
db_user="${DEFAULT_DB_USER}"
db_password=""
db_admin_password=""
client_subnet=""
mysql_host_pattern=""
read_only=false
skip_reconfigure=false

# Estado interno da topologia e configuração
node_mode="unknown"
mysql_config_file=""
mysql_config_modified=false
is_dropin_config=false

# ------------------------------------------------------------------------------
# Função de Ajuda (--help)
# ------------------------------------------------------------------------------
usage() {
    cat <<EOF
Uso: $(basename "$0") [OPÇÕES]

Habilita o acesso de rede ao MySQL/Percona no appliance HPE Morpheus Data Enterprise.
Compatível com topologias Single-Node (Appliance) e Three-Node HA (Percona Cluster).

OPÇÕES:
  -s, --subnet <CIDR|IP>        Sub-rede ou IP de origem autorizado (ex.: 192.168.1.0/24, 10.0.0.0/16, %).
                                Se omitido, detecta automaticamente a rede da interface primária ou solicita via prompt.
  -u, --db-user <USUÁRIO>       Nome do usuário MySQL a ser criado/concedido (padrão: ${DEFAULT_DB_USER}).
  -p, --db-password <SENHA>     Senha do usuário MySQL a criar. Se omitida, uma senha segura será gerada.
  -R, --root-password <SENHA>   Senha de root/admin do MySQL/Percona (opcional; tenta detecção automática).
  -d, --db-name <BANCO>         Nome do banco de dados (padrão: ${DEFAULT_DB_NAME}).
      --read-only               Concede somente privilégios de leitura (SELECT, SHOW VIEW) em vez de ALL PRIVILEGES.
      --skip-reconfigure        Pula 'morpheus-ctl reconfigure' (aplicável apenas no modo Appliance morpheus.rb).
  -b, --backup-dir <DIR>        Diretório base para armazenar os backups (padrão: ${DEFAULT_BACKUP_BASE_DIR}).
  -c, --config <ARQUIVO>        Caminho do arquivo morpheus.rb (padrão: ${DEFAULT_MORPHEUS_CONFIG}).
  -h, --help                    Exibe esta mensagem de ajuda e encerra.

EXEMPLOS:
  sudo $(basename "$0") --subnet 192.168.1.0/24
  sudo $(basename "$0") --subnet 10.10.0.0/16 --db-user relatorios --read-only
  sudo $(basename "$0") -s 192.168.1.50/32 -u dev_app -p 'MinhaSenhaSegura#2026'
  sudo $(basename "$0") -s 192.168.1.0/24 -R 'SenhaRootMySQL'
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
# Validação de Ambiente e Topologia do Morpheus Data
# ------------------------------------------------------------------------------
check_morpheus_environment() {
    # Verifica arquivos de configuração e diretórios canônicos do HPE Morpheus Data
    if [[ -f "${morpheus_config}" || -f "${DEFAULT_SECRETS_FILE}" || -f "/etc/morpheus/morpheus-node.conf" ]]; then
        return 0
    fi
    if [[ -d "/opt/morpheus" || -d "/opt/morpheus-node" || -d "/var/opt/morpheus" || -d "/etc/morpheus" ]]; then
        return 0
    fi
    if command -v morpheus-ctl >/dev/null 2>&1 || command -v morpheus-node-ctl >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

is_mysql_running_locally() {
    # 1. Processo mysqld ativo
    if pgrep -f "mysqld" >/dev/null 2>&1; then
        return 0
    fi
    # 2. Serviço ativo no systemd
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mysqld 2>/dev/null || systemctl is-active --quiet percona-xtradb-cluster 2>/dev/null; then
            return 0
        fi
    fi
    # 3. Serviço ativo no morpheus-ctl
    if command -v morpheus-ctl >/dev/null 2>&1; then
        if morpheus-ctl status mysql 2>&1 | grep -qi "run: mysql"; then
            return 0
        fi
    fi
    # 4. Porta TCP 3306 em escuta local
    if is_port_listening_all_interfaces "${DEFAULT_PORT}" 2>/dev/null; then
        return 0
    fi
    return 1
}

extract_morpheus_db_hosts() {
    local config_file="$1"
    if [[ ! -f "${config_file}" ]]; then
        return 0
    fi
    awk '
        /mysql\[.*host.*\]/ { flag=1; print; next }
        flag && /}/ { print; flag=0 }
        flag && /\]/ { print; flag=0 }
        flag { print }
    ' "${config_file}" | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}|[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" | sort -u || true
}

detect_node_mode() {
    # 1. Validação obrigatória de ambiente Morpheus
    if ! check_morpheus_environment; then
        echo "not_morpheus"
        return 0
    fi

    # 2. Se morpheus.rb existe (Modo Appliance)
    if [[ -f "${morpheus_config}" ]]; then
        # Se mysql['enable'] = false, trata-se de um nó de aplicação Morpheus com banco externo!
        if grep -qE "^\s*mysql\s*\[\s*['\"]enable['\"]\s*\]\s*=\s*false" "${morpheus_config}"; then
            echo "morpheus_app_external_db"
            return 0
        fi

        # Se mysql['enable'] não for false, verifica se o MySQL local está ativo
        if is_mysql_running_locally; then
            echo "appliance"
            return 0
        else
            echo "appliance_mysql_down"
            return 0
        fi
    fi

    # 3. Modo Nó de Cluster Percona / Morpheus Node
    if [[ -f "/etc/morpheus/morpheus-node.conf" || -d "/opt/morpheus-node" || -d "/etc/percona-xtradb-cluster.conf.d" || -d "/etc/mysql" || -f "/etc/my.cnf" ]]; then
        if is_mysql_running_locally; then
            echo "percona_node"
            return 0
        else
            echo "percona_node_stopped"
            return 0
        fi
    fi

    if is_mysql_running_locally; then
        echo "percona_node"
        return 0
    fi

    echo "not_morpheus"
}

# ------------------------------------------------------------------------------
# Localização de Binários e Socket do MySQL
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

    log_error "Cliente MySQL não encontrado no PATH nem nos diretórios padrão (/opt/morpheus, /opt/morpheus-node, /usr/bin)."
    exit 1
}

find_mysql_socket() {
    # 1. Lista de sockets conhecidos do Morpheus e do Percona/MySQL
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

    # 2. Busca dinâmica em sockets abertos por processos mysqld
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

    # 3. Busca rápida no filesystem em diretórios comuns
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

    # 1. Se socket foi detectado e existe, tenta via Unix socket
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

    # 2. Tenta via TCP em 127.0.0.1 na porta do serviço
    local cmd_tcp=("${bin}" "-u" "${user}")
    if [[ -n "${pass}" ]]; then
        cmd_tcp+=("-p${pass}")
    fi
    cmd_tcp+=("-h" "127.0.0.1" "-P" "${DEFAULT_PORT}" "--batch" "-e" "SELECT 1;")
    if "${cmd_tcp[@]}" >/dev/null 2>&1; then
        return 0
    fi

    # 3. Tenta via localhost com protocolo TCP explícito
    local cmd_proto=("${bin}" "-u" "${user}")
    if [[ -n "${pass}" ]]; then
        cmd_proto+=("-p${pass}")
    fi
    cmd_proto+=("-h" "localhost" "--protocol=TCP" "-P" "${DEFAULT_PORT}" "--batch" "-e" "SELECT 1;")
    if "${cmd_proto[@]}" >/dev/null 2>&1; then
        return 0
    fi

    # 4. Tenta invocação direta padrão do cliente MySQL
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
# Descoberta e Validação de Credenciais Administrativas do MySQL/Percona
# ------------------------------------------------------------------------------
get_mysql_admin_auth() {
    local mysql_bin="$1"
    local socket="$2"
    local provided_pwd="$3"

    # 1. Se fornecida explicitamente via parâmetro --root-password
    if [[ -n "${provided_pwd}" ]]; then
        if test_mysql_auth "${mysql_bin}" "${socket}" "root" "${provided_pwd}"; then
            log_ok "Autenticação MySQL root via senha fornecida validada com sucesso."
            echo "${provided_pwd}"
            return 0
        fi
        log_warn "Senha informada em --root-password falhou no teste de autenticação."
    fi

    # 2. Testa conexão sem senha (auth_socket / peer auth no socket Unix)
    if test_mysql_auth "${mysql_bin}" "${socket}" "root" ""; then
        log_ok "Autenticação local do MySQL root autorizada sem senha (auth_socket)."
        echo ""
        return 0
    fi

    # 3. Extração automática de senha dos arquivos de segredos do Morpheus
    local secrets_candidates=(
        "${DEFAULT_SECRETS_FILE}"
        "/var/opt/morpheus/morpheus-secrets.json"
        "/var/opt/morpheus/package-secrets.json"
        "/etc/morpheus/package-secrets.json"
    )

    for sf in "${secrets_candidates[@]}"; do
        if [[ -f "${sf}" ]]; then
            local discovered_passwords=()

            # Extração estruturada via python3 se disponível
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
    # 1. Chaves prioritárias de Percona e MySQL
    for sec in ['percona', 'percona_cluster', 'percona_xtradb_cluster', 'pxc', 'mysql']:
        if sec in d and isinstance(d[sec], dict):
            for k in ['root_password', 'admin_password', 'password', 'cluster_password', 'morpheus_password', 'ops_password']:
                v = d[sec].get(k)
                if v and v not in keys_to_check:
                    keys_to_check.append(v)
    # 2. Chaves de primeiro nível
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

            # Fallback direto com grep/awk no JSON (sem dependência de python)
            if [[ ${#discovered_passwords[@]} -eq 0 ]]; then
                while IFS= read -r pwd_entry; do
                    if [[ -n "${pwd_entry}" ]]; then
                        discovered_passwords+=("${pwd_entry}")
                    fi
                done < <(grep -E '"(root_password|admin_password|percona_password|morpheus_password|ops_password)"\s*:' "${sf}" 2>/dev/null | awk -F'"' '{print $4}' | grep -v '^$' || true)
            fi

            # Testa as senhas descobertas para o usuário 'root'
            for candidate_pwd in "${discovered_passwords[@]}"; do
                if test_mysql_auth "${mysql_bin}" "${socket}" "root" "${candidate_pwd}"; then
                    log_ok "Senha de root do MySQL/Percona recuperada com sucesso de '${sf}'."
                    echo "${candidate_pwd}"
                    return 0
                fi
            done

            # Se root falhar, testa para o usuário 'morpheus' (administrador do esquema)
            for candidate_pwd in "${discovered_passwords[@]}"; do
                if test_mysql_auth "${mysql_bin}" "${socket}" "morpheus" "${candidate_pwd}"; then
                    log_ok "Credenciais de administrador do banco validadas via usuário 'morpheus' (${sf})."
                    echo "__USER__:morpheus:${candidate_pwd}"
                    return 0
                fi
            done
        fi
    done

    # 4. Extração a partir do morpheus.rb (diretivas percona/mysql)
    if [[ -f "${morpheus_config}" ]]; then
        local rb_passwords=()
        while IFS= read -r pwd_entry; do
            if [[ -n "${pwd_entry}" ]]; then
                rb_passwords+=("${pwd_entry}")
            fi
        done < <(grep -E "^\s*(percona|mysql|database)(\[[^]]*\])?\s*\[\s*['\"](root_password|admin_password|password|morpheus_password)['\"]\s*\]\s*=" "${morpheus_config}" 2>/dev/null | awk -F'=' '{print $2}' | tr -d " '\";" || true)

        for candidate_pwd in "${rb_passwords[@]}"; do
            if test_mysql_auth "${mysql_bin}" "${socket}" "root" "${candidate_pwd}"; then
                log_ok "Senha de root do MySQL/Percona recuperada de '${morpheus_config}'."
                echo "${candidate_pwd}"
                return 0
            fi
            if test_mysql_auth "${mysql_bin}" "${socket}" "morpheus" "${candidate_pwd}"; then
                log_ok "Credenciais de administrador do banco validadas via usuário 'morpheus' (${morpheus_config})."
                echo "__USER__:morpheus:${candidate_pwd}"
                return 0
            fi
        done
    fi

    # 5. Verifica /root/.my.cnf
    if [[ -f "/root/.my.cnf" ]]; then
        local cnf_pwd
        cnf_pwd=$(grep -E "^\s*password\s*=" /root/.my.cnf 2>/dev/null | head -n1 | cut -d'=' -f2- | tr -d ' "' || true)
        if [[ -n "${cnf_pwd}" ]] && test_mysql_auth "${mysql_bin}" "${socket}" "root" "${cnf_pwd}"; then
            log_ok "Credenciais de MySQL root recuperadas com sucesso de '/root/.my.cnf'."
            echo "${cnf_pwd}"
            return 0
        fi
    fi

    # 6. Verifica /etc/mysql/debian.cnf (Debian/Ubuntu sys-maint)
    if [[ -f "/etc/mysql/debian.cnf" ]]; then
        local deb_pwd
        deb_pwd=$(grep -E "^\s*password\s*=" /etc/mysql/debian.cnf 2>/dev/null | head -n1 | cut -d'=' -f2- | tr -d ' "' || true)
        local deb_user
        deb_user=$(grep -E "^\s*user\s*=" /etc/mysql/debian.cnf 2>/dev/null | head -n1 | cut -d'=' -f2- | tr -d ' "' || true)
        if [[ -n "${deb_pwd}" && -n "${deb_user}" ]] && test_mysql_auth "${mysql_bin}" "${socket}" "${deb_user}" "${deb_pwd}"; then
            log_ok "Acesso administrativo ao MySQL validado via '${deb_user}' (/etc/mysql/debian.cnf)."
            echo "__USER__:${deb_user}:${deb_pwd}"
            return 0
        fi
    fi

    # 7. Verifica se morpheus-node.conf ou config.yml contêm senhas de banco
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
                    log_ok "Senha do MySQL root recuperada de '${cf}'."
                    echo "${candidate_pwd}"
                    return 0
                fi
            done
        fi
    done

    # 8. Solicitação interativa caso nada tenha funcionado
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

# ------------------------------------------------------------------------------
# Executar Consulta MySQL como Administrador Local
# ------------------------------------------------------------------------------
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
# Detecção de Rede Local e IP Primário
# ------------------------------------------------------------------------------
get_primary_ip() {
    local ip=""
    if command -v ip >/dev/null 2>&1; then
        ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -n1 || true)
        if [[ -z "${ip}" ]]; then
            ip=$(ip -4 addr show scope global 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1 || true)
        fi
    fi

    if [[ -z "${ip}" ]] && command -v hostname >/dev/null 2>&1; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
    fi

    echo "${ip:-127.0.0.1}"
}

detect_default_subnet() {
    local primary_ip
    primary_ip="$(get_primary_ip)"

    if [[ "${primary_ip}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        local o1="${BASH_REMATCH[1]}"
        local o2="${BASH_REMATCH[2]}"
        local o3="${BASH_REMATCH[3]}"
        echo "${o1}.${o2}.${o3}.0/24"
    else
        echo "192.168.1.0/24"
    fi
}

convert_cidr_to_mysql_pattern() {
    local cidr="$1"

    if [[ "${cidr}" == "0.0.0.0/0" || "${cidr}" == "%" ]]; then
        echo "%"
        return 0
    fi

    if [[ "${cidr}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)(/32)?$ ]]; then
        echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}.${BASH_REMATCH[4]}"
        return 0
    fi

    if [[ "${cidr}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\.[0-9]+/24$ ]]; then
        echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}.%"
        return 0
    fi

    if [[ "${cidr}" =~ ^([0-9]+)\.([0-9]+)\.[0-9]+\.[0-9]+/16$ ]]; then
        echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.%.%"
        return 0
    fi

    if [[ "${cidr}" =~ ^([0-9]+)\.[0-9]+\.[0-9]+\.[0-9]+/8$ ]]; then
        echo "${BASH_REMATCH[1]}.%.%.%"
        return 0
    fi

    if [[ "${cidr}" == *"%"* ]]; then
        echo "${cidr}"
        return 0
    fi

    echo "${cidr}"
}

generate_secure_password() {
    local pwd=""
    if command -v openssl >/dev/null 2>&1; then
        pwd=$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9_#%@' | head -c 16 || true)
    fi

    if [[ -z "${pwd}" || ${#pwd} -lt 12 ]]; then
        pwd=$(LC_ALL=C tr -dc 'A-Za-z0-9_#%@' </dev/urandom 2>/dev/null | head -c 16 || true)
    fi

    if [[ -z "${pwd}" ]]; then
        pwd="MorpheusDb_$(date +%s)_Sec!"
    fi

    echo "${pwd}"
}

# ------------------------------------------------------------------------------
# Detecção do Gerenciador de Firewall Ativo
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
# Verificação de Escuta de Porta em Todas as Interfaces
# ------------------------------------------------------------------------------
is_port_listening_all_interfaces() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        if ss -tlnp 2>/dev/null | grep -E "(0\.0\.0\.0|:::|\*):${port}\b" >/dev/null 2>&1; then
            return 0
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -tlnp 2>/dev/null | grep -E "(0\.0\.0\.0|:::|\*):${port}\b" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# ------------------------------------------------------------------------------
# Geração de Backup das Configurações
# ------------------------------------------------------------------------------
create_backup() {
    local backup_dir="$1"
    local fw_backend="$2"

    log_info "Criando snapshot de backup em: ${backup_dir}"
    mkdir -p "${backup_dir}"

    # 1. Backup da configuração do Morpheus / Node
    if [[ "${node_mode}" == "appliance" && -f "${morpheus_config}" ]]; then
        cp -p "${morpheus_config}" "${backup_dir}/morpheus.rb.bak"
        log_ok "Backup de '${morpheus_config}' realizado."
    elif [[ -f "/etc/morpheus/morpheus-node.conf" ]]; then
        cp -p "/etc/morpheus/morpheus-node.conf" "${backup_dir}/morpheus-node.conf.bak"
        log_ok "Backup de '/etc/morpheus/morpheus-node.conf' realizado."
    fi

    # 2. Backup de configuração do MySQL se modificado
    if [[ -n "${mysql_config_file}" && -f "${mysql_config_file}" && "${mysql_config_modified}" == true ]]; then
        cp -p "${mysql_config_file}" "${backup_dir}/mysql-config.bak"
        log_ok "Backup de '${mysql_config_file}' realizado."
    fi

    # 3. Backup do estado do firewall
    if [[ "${fw_backend}" == "firewalld" ]]; then
        firewall-cmd --list-all >"${backup_dir}/firewalld-state.txt" 2>&1 || true
        log_ok "Estado do firewalld salvo."
    elif [[ "${fw_backend}" == "ufw" ]]; then
        ufw status verbose >"${backup_dir}/ufw-state.txt" 2>&1 || true
        log_ok "Estado do ufw salvo."
    elif [[ "${fw_backend}" == "iptables" ]]; then
        iptables-save >"${backup_dir}/iptables-state.rules" 2>&1 || true
        log_ok "Regras do iptables salvas."
    fi

    # 4. Metadados para restauração consistente
    cat <<EOF >"${backup_dir}/backup-metadata.env"
# Metadados gerados em $(date -u +"%Y-%m-%dT%H:%M:%SZ")
BACKUP_TIMESTAMP="${timestamp}"
NODE_MODE="${node_mode}"
MORPHEUS_CONFIG="${morpheus_config}"
MYSQL_CONFIG_FILE="${mysql_config_file}"
MYSQL_CONFIG_MODIFIED="${mysql_config_modified}"
IS_DROPIN_CONFIG="${is_dropin_config}"
DB_NAME="${db_name}"
DB_USER="${db_user}"
SUBNET="${client_subnet}"
MYSQL_HOST_PATTERN="${mysql_host_pattern}"
FIREWALL_BACKEND="${fw_backend}"
READ_ONLY="${read_only}"
EOF

    ln -sfn "${backup_dir}" "${backup_base_dir}/latest"
    log_ok "Ponteiro 'latest' atualizado para: ${backup_dir}"
}

# ------------------------------------------------------------------------------
# Ajuste de Rede no morpheus.rb (Modo Appliance)
# ------------------------------------------------------------------------------
configure_morpheus_rb() {
    log_info "Ajustando diretivas de MySQL em '${morpheus_config}'..."

    if grep -qE "^\s*mysql\s*\[\s*['\"]bind_address['\"]\s*\]" "${morpheus_config}"; then
        sed -i -E "s/^\s*mysql\s*\[\s*['\"]bind_address['\"]\s*\].*/mysql['bind_address'] = '0.0.0.0'/" "${morpheus_config}"
        log_ok "Diretiva mysql['bind_address'] atualizada para '0.0.0.0'."
    else
        cat <<'EOF' >>"${morpheus_config}"

# ==============================================================================
# Habilitação de Acesso Remoto MySQL (Configurado por configure-morpheus-mysql-remote-access.sh)
# ==============================================================================
mysql['enable'] = true
mysql['bind_address'] = '0.0.0.0'
EOF
        log_ok "Diretivas mysql['enable'] e mysql['bind_address'] = '0.0.0.0' adicionadas ao final do arquivo."
    fi
}

# ------------------------------------------------------------------------------
# Ajuste de Rede no MySQL/Percona (Modo Three-Node HA / Percona)
# ------------------------------------------------------------------------------
configure_percona_bind_address() {
    local target_cnf=""
    local candidates=(
        "/etc/mysql/mysql.conf.d/mysqld.cnf"
        "/etc/percona-xtradb-cluster.conf.d/mysqld.cnf"
        "/etc/mysql/my.cnf"
        "/etc/my.cnf"
    )

    for cf in "${candidates[@]}"; do
        if [[ -f "${cf}" ]]; then
            target_cnf="${cf}"
            break
        fi
    done

    if [[ -n "${target_cnf}" ]]; then
        log_info "Arquivo de configuração identificado: ${target_cnf}"
        mysql_config_file="${target_cnf}"
        mysql_config_modified=true

        if grep -qE "^\s*bind-address" "${target_cnf}"; then
            sed -i -E "s/^\s*bind-address\s*=.*/bind-address = 0.0.0.0/" "${target_cnf}"
        else
            if grep -q "\[mysqld\]" "${target_cnf}"; then
                sed -i "/\[mysqld\]/a bind-address = 0.0.0.0" "${target_cnf}"
            else
                echo -e "\n[mysqld]\nbind-address = 0.0.0.0" >>"${target_cnf}"
            fi
        fi
        log_ok "Diretiva bind-address = 0.0.0.0 configurada em '${target_cnf}'."
    else
        local dropin_dir="/etc/mysql/conf.d"
        if [[ ! -d "${dropin_dir}" && -d "/etc/my.cnf.d" ]]; then
            dropin_dir="/etc/my.cnf.d"
        fi
        mkdir -p "${dropin_dir}"
        local dropin_file="${dropin_dir}/99-morpheus-remote.cnf"
        cat <<'EOF' >"${dropin_file}"
[mysqld]
bind-address = 0.0.0.0
EOF
        log_ok "Arquivo drop-in criado: ${dropin_file}"
        mysql_config_file="${dropin_file}"
        mysql_config_modified=true
        is_dropin_config=true
    fi

    log_info "Reiniciando serviço MySQL/Percona para aplicar bind-address..."
    if systemctl restart mysql 2>/dev/null; then
        log_ok "Serviço 'mysql' reiniciado via systemctl."
    elif systemctl restart mysqld 2>/dev/null; then
        log_ok "Serviço 'mysqld' reiniciado via systemctl."
    elif systemctl restart percona-xtradb-cluster 2>/dev/null; then
        log_ok "Serviço 'percona-xtradb-cluster' reiniciado via systemctl."
    else
        log_warn "Não foi possível reiniciar o MySQL automaticamente. Reinicie o serviço manualmente."
    fi
}

# ------------------------------------------------------------------------------
# Aplicação das Regras de Firewall
# ------------------------------------------------------------------------------
apply_firewall_rule() {
    local fw_backend="$1"
    local subnet="$2"

    case "${fw_backend}" in
        firewalld)
            log_info "Adicionando rich rule no firewalld para a sub-rede '${subnet}' na porta ${DEFAULT_PORT}/tcp..."
            firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='${subnet}' port port='${DEFAULT_PORT}' protocol='tcp' accept"
            firewall-cmd --reload
            log_ok "Regra no firewalld aplicada e recarregada com sucesso."
            ;;
        ufw)
            log_info "Liberando porta ${DEFAULT_PORT}/tcp para a sub-rede '${subnet}' no ufw..."
            ufw allow from "${subnet}" to any port "${DEFAULT_PORT}" proto tcp
            log_ok "Regra no ufw aplicada com sucesso."
            ;;
        iptables)
            log_info "Inserindo regra no iptables para a sub-rede '${subnet}' na porta ${DEFAULT_PORT}/tcp..."
            iptables -I INPUT -p tcp -s "${subnet}" --dport "${DEFAULT_PORT}" -j ACCEPT
            log_ok "Regra no iptables inserida na cadeia INPUT."
            ;;
        none)
            log_warn "Nenhum gerenciador de firewall ativo detectado. Portas externas podem ser filtradas por security groups na nuvem ou switch."
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Configuração do Usuário e Privilégios no MySQL
# ------------------------------------------------------------------------------
configure_mysql_user() {
    local mysql_bin="$1"
    local socket="$2"
    local admin_auth="$3"

    log_info "Concedendo privilégios ao usuário '${db_user}'@'${mysql_host_pattern}' no banco '${db_name}'..."

    local grant_sql=""
    if [[ "${read_only}" == true ]]; then
        grant_sql="GRANT SELECT, SHOW VIEW ON \`${db_name}\`.* TO '${db_user}'@'${mysql_host_pattern}';"
    else
        grant_sql="GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'${mysql_host_pattern}';"
    fi

    local sql_script="
CREATE USER IF NOT EXISTS '${db_user}'@'${mysql_host_pattern}' IDENTIFIED BY '${db_password}';
ALTER USER '${db_user}'@'${mysql_host_pattern}' IDENTIFIED BY '${db_password}';
${grant_sql}
FLUSH PRIVILEGES;
"

    run_mysql_admin "${mysql_bin}" "${socket}" "${admin_auth}" "${sql_script}"
    log_ok "Usuário e permissões criados/atualizados no MySQL com sucesso."
}

# ------------------------------------------------------------------------------
# Testes Automatizados de Verificação
# ------------------------------------------------------------------------------
run_verification_tests() {
    local mysql_bin="$1"
    local socket="$2"
    local admin_auth="$3"
    local primary_ip="$4"
    local all_passed=true

    echo ""
    echo "=============================================================================="
    echo "                INICIANDO TESTES AUTOMATIZADOS DE VERIFICAÇÃO                 "
    echo "=============================================================================="

    # Teste 1: Serviço ativo
    log_info "Teste 1/4: Verificando status do daemon MySQL/Percona..."
    local svc_active=false
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mysqld 2>/dev/null || systemctl is-active --quiet percona-xtradb-cluster 2>/dev/null; then
            svc_active=true
        fi
    fi
    if [[ "${svc_active}" == false ]] && command -v morpheus-ctl >/dev/null 2>&1; then
        if morpheus-ctl status mysql 2>&1 | grep -qi "run: mysql"; then
            svc_active=true
        fi
    fi
    if [[ "${svc_active}" == false ]] && pgrep -f "mysqld" >/dev/null 2>&1; then
        svc_active=true
    fi

    if [[ "${svc_active}" == true ]]; then
        log_ok "Daemon MySQL/Percona confirmado em execução."
    else
        log_error "Serviço MySQL não parece estar em execução!"
        all_passed=false
    fi

    # Teste 2: Escuta de porta
    log_info "Teste 2/4: Verificando se a porta ${DEFAULT_PORT} está escutando na rede..."
    if is_port_listening_all_interfaces "${DEFAULT_PORT}"; then
        log_ok "Porta ${DEFAULT_PORT} confirmada em modo de escuta externa (0.0.0.0 / *)."
    else
        log_warn "A porta ${DEFAULT_PORT} pode estar restrita a interfaces locais ou não detectada via ss/netstat."
    fi

    # Teste 3: Autenticação TCP de rede
    log_info "Teste 3/4: Validando autenticação do usuário '${db_user}' via conexão TCP (${primary_ip}:${DEFAULT_PORT})..."
    if "${mysql_bin}" -h "${primary_ip}" -P "${DEFAULT_PORT}" -u "${db_user}" -p"${db_password}" -e "SELECT 'OK' AS status;" "${db_name}" >/dev/null 2>&1; then
        log_ok "Conexão e autenticação via TCP no IP ${primary_ip} bem-sucedidas!"
    elif "${mysql_bin}" -h "127.0.0.1" -P "${DEFAULT_PORT}" -u "${db_user}" -p"${db_password}" -e "SELECT 'OK' AS status;" "${db_name}" >/dev/null 2>&1; then
        log_ok "Autenticação TCP em 127.0.0.1 bem-sucedida! (Nota: O IP ${primary_ip} pode pertencer a uma sub-rede externa ao host local)."
    else
        log_warn "Conexão de teste via TCP falhou. Isso é esperado se o padrão de host '${mysql_host_pattern}' for restrito a outras máquinas remotas e não incluir o IP deste nó."
    fi

    # Teste 4: Consulta de integridade
    log_info "Teste 4/4: Consultando tabelas no banco de dados '${db_name}'..."
    local table_count=""
    table_count=$(run_mysql_admin "${mysql_bin}" "${socket}" "${admin_auth}" "SELECT count(*) FROM information_schema.tables WHERE table_schema = '${db_name}';" 2>/dev/null || echo "0")
    log_ok "Banco de dados '${db_name}' verificado (${table_count} tabelas catalogadas)."

    echo "=============================================================================="
    if [[ "${all_passed}" == true ]]; then
        log_ok "TODOS OS TESTES PRINCIPAIS CONCLUÍDOS COM SUCESSO!"
    else
        log_warn "A configuração foi aplicada, mas um ou mais testes registraram avisos."
    fi
    echo "=============================================================================="
}

# ------------------------------------------------------------------------------
# Banner Final
# ------------------------------------------------------------------------------
display_summary() {
    local primary_ip="$1"
    local backup_path="$2"

    local topo_desc="Appliance Single-Node (Omnibus / morpheus.rb)"
    if [[ "${node_mode}" == "percona_node" ]]; then
        topo_desc="Three-Node HA (Percona XtraDB Cluster / morpheus-node)"
    fi

    cat <<EOF

==============================================================================
               DADOS DE CONEXÃO AO MYSQL/PERCONA DO MORPHEUS
==============================================================================

  Topologia Detectada    : ${topo_desc}
  Host / IP do Nó        : ${primary_ip}
  Porta                  : ${DEFAULT_PORT}
  Banco de Dados         : ${db_name}
  Usuário de Acesso      : ${db_user}
  Senha                  : ${db_password}
  Sub-rede Autorizada    : ${client_subnet} (Padrão MySQL: '${mysql_host_pattern}')
  Modo de Acesso         : $(if [[ "${read_only}" == true ]]; then echo "Somente Leitura (SELECT, SHOW VIEW)"; else echo "Completo (ALL PRIVILEGES)"; fi)
  Backup das Configurações: ${backup_path}

------------------------------------------------------------------------------
  MATRIZ DE PERMISSÕES: '${db_user}' vs 'root' DO MYSQL:
------------------------------------------------------------------------------
  Capacidade / Privilégio                       | 'root' | '${db_user}'
  ----------------------------------------------+--------+--------------------
  Consultar dados no '${db_name}' (SELECT)              |  SIM   |  SIM (Concedido)
  Inserir / Alterar / Apagar dados (DML)        |  SIM   |  $(if [[ "${read_only}" == true ]]; then echo "NÃO (Bloqueado por --read-only)"; else echo "SIM (Concedido)"; fi)
  Criar / Alterar / Dropar tabelas (DDL)        |  SIM   |  $(if [[ "${read_only}" == true ]]; then echo "NÃO (Bloqueado por --read-only)"; else echo "SIM (Concedido)"; fi)
  Acessar outros bancos (mysql, sys, perf_sch)  |  SIM   |  NÃO (Restrito ao '${db_name}')
  Criar / Excluir outros usuários (GRANT OPTION)|  SIM   |  NÃO (Sem permissão)
  Alterar parâmetros globais (SET GLOBAL)       |  SIM   |  NÃO (Sem SUPER admin)
  Gerenciar nós do cluster de banco             |  SIM   |  NÃO (Sem privilégios)
  Desligar o serviço MySQL (SHUTDOWN)           |  SIM   |  NÃO (Sem permissão)
  Ver processos de outros usuários (PROCESSLIST)|  SIM   |  NÃO (Vê apenas os seus)

------------------------------------------------------------------------------
  COMO CONECTAR ATRAVÉS DE OUTRA MÁQUINA DA REDE LOCAL:
------------------------------------------------------------------------------

1) Teste rápido de porta de rede (Linux / macOS):
   nc -zv ${primary_ip} ${DEFAULT_PORT}

2) Teste de porta de rede (Windows PowerShell):
   Test-NetConnection -ComputerName ${primary_ip} -Port ${DEFAULT_PORT}

3) Conexão direta via cliente oficial MySQL CLI:
   mysql -h ${primary_ip} -P ${DEFAULT_PORT} -u ${db_user} -p'${db_password}' ${db_name}

4) String de Conexão JDBC / Ferramentas Gráficas (DBeaver, DataGrip, Workbench):
   - Driver : MySQL / MariaDB
   - Host   : ${primary_ip}
   - Porta  : ${DEFAULT_PORT}
   - Banco  : ${db_name}
   - Usuário: ${db_user}
   - Senha  : ${db_password}
   - URL    : jdbc:mysql://${primary_ip}:${DEFAULT_PORT}/${db_name}?useSSL=false

------------------------------------------------------------------------------
  CONSIDERAÇÕES PARA TOPOLOGIAS THREE-NODE HA (PERCONA CLUSTER):
------------------------------------------------------------------------------
  • Como seu cluster opera em replicação síncrona de banco (3 nós), os privilégios
    do usuário '${db_user}' criados aqui são REPLICADOS AUTOMATICAMENTE aos outros nós.
  • A regra de firewall na porta ${DEFAULT_PORT} foi aplicada localmente neste nó. Se
    desejar conectar apontando para os outros nós diretamente, execute o script
    neles informando o mesmo '--subnet'.
  • Para reverter todas as alterações a qualquer momento, execute:
    sudo ./restore-morpheus-mysql-remote-access.sh --backup-dir "${backup_path}"
==============================================================================

EOF
}

# ------------------------------------------------------------------------------
# Função Principal (main)
# ------------------------------------------------------------------------------
main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s | --subnet)
                client_subnet="${2:-}"
                shift 2
                ;;
            -u | --db-user)
                db_user="${2:-}"
                shift 2
                ;;
            -p | --db-password)
                db_password="${2:-}"
                shift 2
                ;;
            -R | --root-password)
                db_admin_password="${2:-}"
                shift 2
                ;;
            -d | --db-name)
                db_name="${2:-}"
                shift 2
                ;;
            --read-only)
                read_only=true
                shift
                ;;
            --skip-reconfigure)
                skip_reconfigure=true
                shift
                ;;
            -b | --backup-dir)
                backup_base_dir="${2:-}"
                shift 2
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

    # Detecção e validação rigorosa da topologia do nó
    local detected_mode
    detected_mode="$(detect_node_mode)"
    node_mode="${detected_mode}"

    case "${node_mode}" in
        not_morpheus)
            log_error "=============================================================================="
            log_error "FALHA DE VALIDAÇÃO: AMBIENTE MORPHEUS DATA NÃO DETECTADO!"
            log_error "=============================================================================="
            log_error "Este servidor não foi identificado como um ambiente HPE Morpheus Data Enterprise."
            log_error "Nenhum arquivo de configuração ou diretório de instalação do Morpheus foi encontrado:"
            log_error "  • ${morpheus_config}"
            log_error "  • ${DEFAULT_SECRETS_FILE}"
            log_error "  • /etc/morpheus/morpheus-node.conf"
            log_error "  • /opt/morpheus ou /opt/morpheus-node"
            log_error "  • /var/opt/morpheus"
            log_error ""
            log_error "Execução abortada por segurança para evitar alterações indevidas neste host."
            log_error "=============================================================================="
            exit 1
            ;;
        morpheus_app_external_db)
            log_error "=============================================================================="
            log_error "ERRO: EXECUTADO EM UM NÓ DE APLICAÇÃO MORPHEUS COM BANCO DE DADOS EXTERNO!"
            log_error "=============================================================================="
            log_error "O arquivo '${morpheus_config}' define: mysql['enable'] = false."
            log_error "Este servidor ($(hostname)) atua como Nó de Aplicação/Interface (morpheus-ui / workers),"
            log_error "portanto o daemon MySQL/Percona NÃO é executado localmente aqui."
            log_error ""
            log_error "O script de liberação de acesso remoto ao MySQL deve ser executado diretamente"
            log_error "em um dos NÓS DO CLUSTER PERCONA XTRADB ou em um Appliance Single-Node com banco local."

            local detected_db_hosts
            detected_db_hosts="$(extract_morpheus_db_hosts "${morpheus_config}")"
            if [[ -n "${detected_db_hosts}" ]]; then
                log_error ""
                log_error "Nós de banco de dados Percona configurados na diretiva mysql['host']:"
                while IFS= read -r db_h; do
                    log_error "  -> ${db_h}"
                done <<< "${detected_db_hosts}"
            fi
            log_error ""
            log_error "Conecte-se via SSH a um dos nós de banco de dados acima e execute o script lá."
            log_error "=============================================================================="
            exit 1
            ;;
        appliance_mysql_down)
            log_error "=============================================================================="
            log_error "ERRO: SERVIÇO MYSQL LOCAL NÃO ESTÁ EM EXECUÇÃO NO APPLIANCE!"
            log_error "=============================================================================="
            log_error "O arquivo '${morpheus_config}' foi detectado, mas o daemon MySQL não está ativo."
            log_error "Inicie o serviço com 'morpheus-ctl start mysql' e execute o script novamente."
            log_error "=============================================================================="
            exit 1
            ;;
        percona_node_stopped)
            log_error "=============================================================================="
            log_error "ERRO: SERVIÇO MYSQL/PERCONA NÃO ESTÁ EM EXECUÇÃO NESTE NÓ DE CLUSTER!"
            log_error "=============================================================================="
            log_error "Arquivos de configuração do Percona/Morpheus foram encontrados, mas o daemon"
            log_error "mysqld não está rodando nem escutando na porta ${DEFAULT_PORT} deste host."
            log_error "Inicie o serviço (ex.: 'systemctl start mysql' ou 'percona-xtradb-cluster') e tente novamente."
            log_error "=============================================================================="
            exit 1
            ;;
        appliance)
            log_info "Modo de implantação detectado: Single-Node Morpheus Appliance com banco local."
            ;;
        percona_node)
            log_info "Modo de implantação detectado: Nó de Cluster Morpheus Data (Percona XtraDB Cluster / morpheus-node)."
            ;;
    esac

    # Resolução da sub-rede se não fornecida
    if [[ -z "${client_subnet}" ]]; then
        local suggested_subnet
        suggested_subnet="$(detect_default_subnet)"
        echo -n "Informe a sub-rede/IP autorizado a conectar (pressione Enter para '${suggested_subnet}'): "
        read -r user_input_subnet
        client_subnet="${user_input_subnet:-${suggested_subnet}}"
    fi

    if [[ -z "${client_subnet}" ]]; then
        log_error "Sub-rede é obrigatória."
        exit 1
    fi

    mysql_host_pattern="$(convert_cidr_to_mysql_pattern "${client_subnet}")"

    # Geração da senha do usuário de acesso caso não fornecida
    if [[ -z "${db_password}" ]]; then
        db_password="$(generate_secure_password)"
    fi

    local timestamp
    timestamp="$(date +"%Y%m%d_%H%M%S")"
    readonly timestamp

    local current_backup_dir
    current_backup_dir="${backup_base_dir}/backup-${timestamp}"
    readonly current_backup_dir

    # Descoberta de serviços e binários
    log_info "Detectando binários e ambiente do Morpheus/MySQL..."
    local mysql_bin
    mysql_bin="$(find_mysql_bin)"
    readonly mysql_bin

    local mysql_socket
    mysql_socket="$(find_mysql_socket)"
    readonly mysql_socket

    local primary_ip
    primary_ip="$(get_primary_ip)"
    readonly primary_ip

    local fw_backend
    fw_backend="$(detect_firewall_backend)"
    readonly fw_backend

    log_ok "Binário MySQL   : ${mysql_bin}"
    log_ok "Socket MySQL    : ${mysql_socket:-'não encontrado (tentará porta TCP/padrão)'}"
    log_ok "IP Primário     : ${primary_ip}"
    log_ok "Backend Firewall: ${fw_backend}"

    # Validação de credenciais root/admin do MySQL
    local admin_auth
    admin_auth="$(get_mysql_admin_auth "${mysql_bin}" "${mysql_socket}" "${db_admin_password}")"
    readonly admin_auth

    # Configuração de escuta de rede (bind_address) de acordo com o modo
    if [[ "${node_mode}" == "appliance" ]]; then
        configure_morpheus_rb
        if [[ "${skip_reconfigure}" == false ]]; then
            log_info "Executando 'morpheus-ctl reconfigure' para aplicar diretivas de rede..."
            if command -v morpheus-ctl >/dev/null 2>&1; then
                morpheus-ctl reconfigure
            elif [[ -x "/usr/bin/morpheus-ctl" ]]; then
                /usr/bin/morpheus-ctl reconfigure
            fi
            log_ok "Reconfiguração do Morpheus concluída."
        fi
    elif [[ "${node_mode}" == "percona_node" ]]; then
        if is_port_listening_all_interfaces "${DEFAULT_PORT}"; then
            log_ok "MySQL/Percona já está escutando em todas as interfaces (0.0.0.0:${DEFAULT_PORT})."
            log_ok "Nenhuma alteração nos arquivos de configuração do MySQL necessária."
            mysql_config_modified=false
        else
            log_info "Porta ${DEFAULT_PORT} não está aberta para todas as interfaces. Ajustando bind-address..."
            configure_percona_bind_address
        fi
    fi

    # 1. Geração de Backup
    create_backup "${current_backup_dir}" "${fw_backend}"

    # 2. Liberação no Firewall
    apply_firewall_rule "${fw_backend}" "${client_subnet}"

    # 3. Concessão de Privilégios no MySQL
    configure_mysql_user "${mysql_bin}" "${mysql_socket}" "${admin_auth}"

    # 4. Testes Automatizados de Validação
    run_verification_tests "${mysql_bin}" "${mysql_socket}" "${admin_auth}" "${primary_ip}"

    # 5. Exibição do Resumo Final com Credenciais e Instruções
    display_summary "${primary_ip}" "${current_backup_dir}"
}

main "$@"
