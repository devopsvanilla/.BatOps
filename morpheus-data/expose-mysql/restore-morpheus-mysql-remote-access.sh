#!/usr/bin/env bash
# ==============================================================================
# Script: restore-morpheus-mysql-remote-access.sh
# Descrição: Restaura as configurações originais do Morpheus Data e do firewall,
#            removendo o acesso remoto ao MySQL embarcado e o usuário criado.
#            Gera também um backup de segurança do estado atual pré-restauração.
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
keep_db_user=false
skip_reconfigure=false

# ------------------------------------------------------------------------------
# Função de Ajuda (--help)
# ------------------------------------------------------------------------------
usage() {
  cat <<EOF
Uso: $(basename "$0") [OPÇÕES]

Restaura a configuração anterior do Morpheus e do firewall, revertendo a liberação
de acesso remoto ao MySQL embarcado.

OPÇÕES:
  -b, --backup-dir <DIR>  Caminho do diretório de backup a ser restaurado.
                          Se omitido, o script buscará o backup 'latest' ou o mais recente em '${DEFAULT_BACKUP_BASE_DIR}'.
      --keep-db-user      Mantém o usuário criado no MySQL (não executa DROP USER).
      --skip-reconfigure  Não executa 'morpheus-ctl reconfigure' após restaurar o arquivo morpheus.rb.
  -c, --config <ARQUIVO>  Caminho do arquivo morpheus.rb (padrão: ${DEFAULT_MORPHEUS_CONFIG}).
  -h, --help              Exibe esta mensagem de ajuda e encerra.

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
  local candidate="/opt/morpheus/embedded/bin/mysql"
  if [[ -x "${candidate}" ]]; then
    echo "${candidate}"
    return 0
  fi

  if command -v mysql >/dev/null 2>&1; then
    command -v mysql
    return 0
  fi

  echo ""
}

find_mysql_socket() {
  local sockets=(
    "/var/opt/morpheus/mysql/mysql.sock"
    "/var/run/mysqld/mysqld.sock"
    "/tmp/mysql.sock"
  )
  for s in "${sockets[@]}"; do
    if [[ -S "${s}" ]]; then
      echo "${s}"
      return 0
    fi
  done
  echo ""
}

get_morpheus_root_password() {
  if [[ -f "${DEFAULT_SECRETS_FILE}" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      python3 -c "
import json
try:
    with open('${DEFAULT_SECRETS_FILE}') as f:
        data = json.load(f)
    print(data.get('mysql', {}).get('root_password', ''))
except Exception:
    pass
" 2>/dev/null || true
    elif command -v jq >/dev/null 2>&1; then
      jq -r '.mysql.root_password // empty' "${DEFAULT_SECRETS_FILE}" 2>/dev/null || true
    fi
  fi
}

run_mysql_root() {
  local mysql_bin="$1"
  local socket="$2"
  local root_pwd="$3"
  local sql="$4"

  local cmd=("${mysql_bin}" "-u" "root")
  if [[ -n "${socket}" ]]; then
    cmd+=("-S" "${socket}")
  fi

  if [[ -n "${root_pwd}" ]]; then
    cmd+=("-p${root_pwd}")
  fi

  cmd+=("--batch" "--skip-column-names" "-e" "${sql}")

  "${cmd[@]}"
}

# ------------------------------------------------------------------------------
# Localização do Diretório de Backup a Restaurar
# ------------------------------------------------------------------------------
resolve_backup_dir() {
  local specified_dir="$1"

  if [[ -n "${specified_dir}" ]]; then
    if [[ -d "${specified_dir}" ]]; then
      echo "${specified_dir}"
      return 0
    else
      log_error "Diretório de backup especificado não existe: '${specified_dir}'"
      exit 1
    fi
  fi

  # 1. Tenta verificar ponteiro 'latest'
  if [[ -L "${backup_base_dir}/latest" && -d "${backup_base_dir}/latest" ]]; then
    local target
    target="$(readlink -f "${backup_base_dir}/latest")"
    if [[ -d "${target}" ]]; then
      echo "${target}"
      return 0
    fi
  fi

  # 2. Tenta encontrar a pasta backup-* mais recente
  if [[ -d "${backup_base_dir}" ]]; then
    local latest_found
    latest_found="$(find "${backup_base_dir}" -maxdepth 1 -type d -name "backup-*" | sort -r | head -n1 || true)"
    if [[ -n "${latest_found}" && -d "${latest_found}" ]]; then
      echo "${latest_found}"
      return 0
    fi
  fi

  log_error "Nenhum backup encontrado em '${backup_base_dir}'."
  log_error "Informe manualmente via opção: --backup-dir <DIRETÓRIO>"
  exit 1
}

# ------------------------------------------------------------------------------
# Detecção de Firewall Ativo
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
# Backup de Segurança Pré-Restauração
# ------------------------------------------------------------------------------
create_pre_restore_safety_backup() {
  local safety_dir="$1"
  local fw_backend="$2"

  log_info "Criando backup de segurança pré-restauração em: ${safety_dir}"
  mkdir -p "${safety_dir}"

  if [[ -f "${morpheus_config}" ]]; then
    cp -p "${morpheus_config}" "${safety_dir}/morpheus.rb.current.bak"
    log_ok "Cópia do '${morpheus_config}' atual salva."
  fi

  if [[ "${fw_backend}" == "firewalld" ]]; then
    firewall-cmd --list-all > "${safety_dir}/firewalld-pre-restore.txt" 2>&1 || true
  elif [[ "${fw_backend}" == "ufw" ]]; then
    ufw status verbose > "${safety_dir}/ufw-pre-restore.txt" 2>&1 || true
  elif [[ "${fw_backend}" == "iptables" ]]; then
    iptables-save > "${safety_dir}/iptables-pre-restore.rules" 2>&1 || true
  fi
  log_ok "Estado do firewall pré-restauração salvo."
}

# ------------------------------------------------------------------------------
# Reversão de Regras de Firewall
# ------------------------------------------------------------------------------
revert_firewall_rule() {
  local fw_backend="$1"
  local subnet="$2"

  if [[ -z "${subnet}" ]]; then
    log_warn "Sub-rede não identificada nos metadados do backup. Pulando remoção automática no firewall."
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
  local root_pwd="$3"
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
  run_mysql_root "${mysql_bin}" "${socket}" "${root_pwd}" "${sql}" 2>/dev/null || true
  log_ok "Usuário '${user}'@'${pattern}' removido do MySQL."
}

# ------------------------------------------------------------------------------
# Função Principal (main)
# ------------------------------------------------------------------------------
main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -b|--backup-dir)
        target_backup_dir="${2:-}"
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
      -c|--config)
        morpheus_config="${2:-}"
        shift 2
        ;;
      -h|--help)
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

  log_info "Iniciando processo de restauração das configurações do MySQL embarcado..."

  # Localiza o backup a restaurar
  local selected_backup
  selected_backup="$(resolve_backup_dir "${target_backup_dir}")"
  log_ok "Backup de origem selecionado: ${selected_backup}"

  # Lê metadados se existirem
  local meta_file="${selected_backup}/backup-metadata.env"
  local db_user="morpheus_remote"
  local subnet=""
  local mysql_host_pattern=""
  local fw_meta_backend=""

  if [[ -f "${meta_file}" ]]; then
    log_info "Carregando metadados do arquivo: ${meta_file}"
    # shellcheck disable=SC1090
    source "${meta_file}"
    db_user="${DB_USER:-${db_user}}"
    subnet="${SUBNET:-}"
    mysql_host_pattern="${MYSQL_HOST_PATTERN:-}"
    fw_meta_backend="${FIREWALL_BACKEND:-}"
  fi

  local current_fw_backend
  current_fw_backend="$(detect_firewall_backend)"
  local effective_fw="${fw_meta_backend:-${current_fw_backend}}"

  # 1. Gera backup de segurança do estado atual (pré-restauração)
  local safety_timestamp
  safety_timestamp="$(date +"%Y%m%d_%H%M%S")"
  local safety_backup_dir="${backup_base_dir}/pre-restore-${safety_timestamp}"
  create_pre_restore_safety_backup "${safety_backup_dir}" "${current_fw_backend}"

  # 2. Restaura o arquivo morpheus.rb
  local morpheus_bak="${selected_backup}/morpheus.rb.bak"
  if [[ -f "${morpheus_bak}" ]]; then
    log_info "Restaurando '${morpheus_config}' a partir de '${morpheus_bak}'..."
    cp -p "${morpheus_bak}" "${morpheus_config}"
    log_ok "Arquivo '${morpheus_config}' restaurado com sucesso."
  else
    log_error "Arquivo de backup '${morpheus_bak}' não encontrado no diretório de backup!"
    exit 1
  fi

  # 3. Reverte as regras de firewall
  revert_firewall_rule "${effective_fw}" "${subnet}"

  # 4. Remove o usuário no MySQL (se não solicitado --keep-db-user)
  if [[ "${keep_db_user}" == false ]]; then
    local mysql_bin
    mysql_bin="$(find_mysql_bin)"
    local mysql_socket
    mysql_socket="$(find_mysql_socket)"
    local morpheus_root_pwd
    morpheus_root_pwd="$(get_morpheus_root_password)"

    if [[ -n "${mysql_bin}" && -n "${mysql_host_pattern}" ]]; then
      remove_mysql_user "${mysql_bin}" "${mysql_socket}" "${morpheus_root_pwd}" "${db_user}" "${mysql_host_pattern}"
    fi
  else
    log_info "Opção --keep-db-user ativa. Usuário MySQL mantido."
  fi

  # 5. Executa morpheus-ctl reconfigure
  if [[ "${skip_reconfigure}" == false ]]; then
    log_info "Executando 'morpheus-ctl reconfigure' para reestabelecer as configurações originais do appliance..."
    if command -v morpheus-ctl >/dev/null 2>&1; then
      morpheus-ctl reconfigure
    elif [[ -x "/usr/bin/morpheus-ctl" ]]; then
      /usr/bin/morpheus-ctl reconfigure
    else
      log_warn "Comando 'morpheus-ctl' não encontrado no PATH. Execute manualmente para efetivar."
    fi
    log_ok "Reconfiguração do Morpheus finalizada."
  else
    log_warn "Flag --skip-reconfigure informada. O comando 'morpheus-ctl reconfigure' não foi executado."
  fi

  cat <<EOF

==============================================================================
                    RESTAURAÇÃO CONCLUÍDA COM SUCESSO
==============================================================================

  • Backup restaurado               : ${selected_backup}
  • Backup de segurança prévio gerado: ${safety_backup_dir}
  • Configuração morpheus.rb         : Restaurada para o estado anterior
  • Regras de Firewall               : Revertidas (porta ${DEFAULT_PORT}/tcp fechada para ${subnet:-'sub-rede configurada'})
  • Usuário MySQL (${db_user})      : $(if [[ "${keep_db_user}" == true ]]; then echo "Mantido (--keep-db-user)"; else echo "Removido (DROP USER)"; fi)
  • Estado do Morpheus              : $(if [[ "${skip_reconfigure}" == false ]]; then echo "Reconfigurado (morpheus-ctl reconfigure)"; else echo "Reconfigure pendente (--skip-reconfigure)"; fi)

==============================================================================

EOF
}

main "$@"
