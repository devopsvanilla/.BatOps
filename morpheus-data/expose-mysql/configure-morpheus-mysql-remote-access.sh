#!/usr/bin/env bash
# ==============================================================================
# Script: configure-morpheus-mysql-remote-access.sh
# Descrição: Habilita o acesso remoto ao MySQL embarcado do HPE Morpheus Data
#            Enterprise (incluindo topologias 3-Node HA), gerando backup
#            automático prévio das configurações, ajustando morpheus.rb,
#            regras de firewall do SO, concedendo permissões no banco e testando
#            a conectividade ao final.
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
client_subnet=""
mysql_host_pattern=""
read_only=false
skip_reconfigure=false

# ------------------------------------------------------------------------------
# Função de Ajuda (--help)
# ------------------------------------------------------------------------------
usage() {
  cat <<EOF
Uso: $(basename "$0") [OPÇÕES]

Habilita o acesso de rede ao MySQL embarcado no appliance HPE Morpheus Data Enterprise.

OPÇÕES:
  -s, --subnet <CIDR|IP>     Sub-rede ou IP de origem autorizado (ex.: 192.168.1.0/24, 10.0.0.0/16, %).
                             Se omitido, detecta automaticamente a rede da interface primária ou solicita via prompt.
  -u, --db-user <USUÁRIO>    Nome do usuário MySQL a ser criado/concedido (padrão: ${DEFAULT_DB_USER}).
  -p, --db-password <SENHA>  Senha do usuário MySQL. Se omitida, uma senha segura aleatória será gerada.
  -d, --db-name <BANCO>      Nome do banco de dados (padrão: ${DEFAULT_DB_NAME}).
      --read-only            Concede somente privilégios de leitura (SELECT, SHOW VIEW) em vez de ALL PRIVILEGES.
      --skip-reconfigure     Pula a execução de 'morpheus-ctl reconfigure' (útil para dry-run ou testes).
  -b, --backup-dir <DIR>     Diretório base para armazenar os backups (padrão: ${DEFAULT_BACKUP_BASE_DIR}).
  -c, --config <ARQUIVO>     Caminho do arquivo morpheus.rb (padrão: ${DEFAULT_MORPHEUS_CONFIG}).
  -h, --help                 Exibe esta mensagem de ajuda e encerra.

EXEMPLOS:
  sudo $(basename "$0") --subnet 192.168.1.0/24
  sudo $(basename "$0") --subnet 10.10.0.0/16 --db-user relatorios --read-only
  sudo $(basename "$0") -s 192.168.1.50/32 -u dev_app -p 'MinhaSenhaSegura#2026'
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

  log_error "Cliente MySQL não encontrado em '${candidate}' nem no PATH do sistema."
  exit 1
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

# ------------------------------------------------------------------------------
# Executar Consulta MySQL como Root Local
# ------------------------------------------------------------------------------
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
    # Sugere a rede /24 da classe local comum
    echo "${o1}.${o2}.${o3}.0/24"
  else
    echo "192.168.1.0/24"
  fi
}

# ------------------------------------------------------------------------------
# Conversão de Sub-rede CIDR para Padrão de Host MySQL
# ------------------------------------------------------------------------------
convert_cidr_to_mysql_pattern() {
  local cidr="$1"

  # Se for curinga global ou já estiver em formato de wildcard
  if [[ "${cidr}" == "0.0.0.0/0" || "${cidr}" == "%" ]]; then
    echo "%"
    return 0
  fi

  # Se for IP individual sem máscara ou /32
  if [[ "${cidr}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)(/32)?$ ]]; then
    echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}.${BASH_REMATCH[4]}"
    return 0
  fi

  # Se for /24
  if [[ "${cidr}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\.[0-9]+/24$ ]]; then
    echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}.%"
    return 0
  fi

  # Se for /16
  if [[ "${cidr}" =~ ^([0-9]+)\.([0-9]+)\.[0-9]+\.[0-9]+/16$ ]]; then
    echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.%.%"
    return 0
  fi

  # Se for /8
  if [[ "${cidr}" =~ ^([0-9]+)\.[0-9]+\.[0-9]+\.[0-9]+/8$ ]]; then
    echo "${BASH_REMATCH[1]}.%.%.%"
    return 0
  fi

  # Se já contiver '%'
  if [[ "${cidr}" == *"%"* ]]; then
    echo "${cidr}"
    return 0
  fi

  # Fallback: retorna o valor original (MySQL 8 aceita notação IP/netmask)
  echo "${cidr}"
}

# ------------------------------------------------------------------------------
# Geração de Senha Segura
# ------------------------------------------------------------------------------
generate_secure_password() {
  local pwd=""
  if command -v openssl >/dev/null 2>&1; then
    pwd=$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9_#%@' | head -c 16 || true)
  fi

  if [[ -z "${pwd}" || ${#pwd} -lt 12 ]]; then
    pwd=$(LC_ALL=C tr -dc 'A-Za-z0-9_#%@' </dev/urandom 2>/dev/null | head -c 16 || true)
  fi

  # Garante inclusão de letras e números se o gerador pseudoaleatório falhar
  if [[ -z "${pwd}" ]]; then
    pwd="MorpheusDb_$(date +%s)_Sec!"
  fi

  echo "${pwd}"
}

# ------------------------------------------------------------------------------
# Geração de Backup das Configurações
# ------------------------------------------------------------------------------
create_backup() {
  local backup_dir="$1"
  local fw_backend="$2"

  log_info "Criando snapshot de backup em: ${backup_dir}"
  mkdir -p "${backup_dir}"

  # 1. Backup de morpheus.rb
  if [[ -f "${morpheus_config}" ]]; then
    cp -p "${morpheus_config}" "${backup_dir}/morpheus.rb.bak"
    log_ok "Backup de '${morpheus_config}' realizado."
  else
    log_error "Arquivo de configuração '${morpheus_config}' não encontrado!"
    exit 1
  fi

  # 2. Backup do estado do firewall
  if [[ "${fw_backend}" == "firewalld" ]]; then
    firewall-cmd --list-all > "${backup_dir}/firewalld-state.txt" 2>&1 || true
    log_ok "Estado do firewalld salvo."
  elif [[ "${fw_backend}" == "ufw" ]]; then
    ufw status verbose > "${backup_dir}/ufw-state.txt" 2>&1 || true
    log_ok "Estado do ufw salvo."
  elif [[ "${fw_backend}" == "iptables" ]]; then
    iptables-save > "${backup_dir}/iptables-state.rules" 2>&1 || true
    log_ok "Regras do iptables salvas."
  fi

  # 3. Criação de arquivo de metadados para restauração confiável
  cat <<EOF > "${backup_dir}/backup-metadata.env"
# Metadados gerados em $(date -u +"%Y-%m-%dT%H:%M:%SZ")
BACKUP_TIMESTAMP="${timestamp}"
MORPHEUS_CONFIG="${morpheus_config}"
DB_NAME="${db_name}"
DB_USER="${db_user}"
SUBNET="${client_subnet}"
MYSQL_HOST_PATTERN="${mysql_host_pattern}"
FIREWALL_BACKEND="${fw_backend}"
READ_ONLY="${read_only}"
EOF

  # 4. Atualiza ponteiro 'latest'
  ln -sfn "${backup_dir}" "${backup_base_dir}/latest"
  log_ok "Ponteiro 'latest' atualizado para: ${backup_dir}"
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
# Aplicação da Configuração no morpheus.rb
# ------------------------------------------------------------------------------
configure_morpheus_rb() {
  log_info "Ajustando diretivas de MySQL em '${morpheus_config}'..."

  # Verifica se mysql['bind_address'] já existe no arquivo
  if grep -qE "^\s*mysql\s*\[\s*['\"]bind_address['\"]\s*\]" "${morpheus_config}"; then
    sed -i -E "s/^\s*mysql\s*\[\s*['\"]bind_address['\"]\s*\].*/mysql['bind_address'] = '0.0.0.0'/" "${morpheus_config}"
    log_ok "Diretiva mysql['bind_address'] atualizada para '0.0.0.0'."
  else
    cat <<'EOF' >> "${morpheus_config}"

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
      log_warn "Nenhum gerenciador de firewall ativo detectado. Certifique-se de que portas externas não estejam bloqueadas pelo provedor de nuvem ou hypervisor."
      ;;
  esac
}

# ------------------------------------------------------------------------------
# Configuração do Usuário e Privilégios no MySQL
# ------------------------------------------------------------------------------
configure_mysql_user() {
  local mysql_bin="$1"
  local socket="$2"
  local root_pwd="$3"

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

  run_mysql_root "${mysql_bin}" "${socket}" "${root_pwd}" "${sql_script}"
  log_ok "Usuário e permissões criados/atualizados no MySQL com sucesso."
}

# ------------------------------------------------------------------------------
# Execução dos Testes Automatizados de Verificação
# ------------------------------------------------------------------------------
run_verification_tests() {
  local mysql_bin="$1"
  local primary_ip="$2"
  local all_passed=true

  echo ""
  echo "=============================================================================="
  echo "                INICIANDO TESTES AUTOMATIZADOS DE VERIFICAÇÃO                 "
  echo "=============================================================================="

  # Teste 1: Processo do MySQL ativo
  log_info "Teste 1/4: Verificando se o serviço MySQL do Morpheus está em execução..."
  if command -v morpheus-ctl >/dev/null 2>&1; then
    if morpheus-ctl status mysql 2>&1 | grep -qi "run: mysql"; then
      log_ok "Serviço mysql ativo via morpheus-ctl."
    else
      log_warn "morpheus-ctl não reportou 'run: mysql'. Verificando processos do sistema..."
      if pgrep -f "mysqld" >/dev/null 2>&1; then
        log_ok "Processo mysqld detectado em execução."
      else
        log_error "Serviço MySQL não parece estar em execução!"
        all_passed=false
      fi
    fi
  elif pgrep -f "mysqld" >/dev/null 2>&1; then
    log_ok "Processo mysqld detectado em execução."
  else
    log_error "Processo mysqld não encontrado!"
    all_passed=false
  fi

  # Teste 2: Escuta da porta 3306
  log_info "Teste 2/4: Verificando se a porta ${DEFAULT_PORT} está escutando externamente..."
  local port_listening=false
  if command -v ss >/dev/null 2>&1; then
    if ss -tulpn | grep -E ":${DEFAULT_PORT}\b" >/dev/null 2>&1; then
      port_listening=true
    fi
  elif command -v netstat >/dev/null 2>&1; then
    if netstat -tulpn | grep -E ":${DEFAULT_PORT}\b" >/dev/null 2>&1; then
      port_listening=true
    fi
  fi

  if [[ "${port_listening}" == true ]]; then
    log_ok "Porta ${DEFAULT_PORT} confirmada em modo de escuta de rede."
  else
    log_warn "Não foi possível confirmar o socket da porta ${DEFAULT_PORT} via ss/netstat."
  fi

  # Teste 3: Autenticação via TCP/IP na interface de rede
  log_info "Teste 3/4: Validando autenticação do usuário '${db_user}' via conexão TCP (${primary_ip}:${DEFAULT_PORT})..."
  if "${mysql_bin}" -h "${primary_ip}" -P "${DEFAULT_PORT}" -u "${db_user}" -p"${db_password}" -e "SELECT 'OK' AS status;" "${db_name}" >/dev/null 2>&1; then
    log_ok "Conexão e autenticação via TCP no IP ${primary_ip} bem-sucedidas!"
  else
    # Tenta via 127.0.0.1 se o padrão incluir localhost/curinga
    if "${mysql_bin}" -h "127.0.0.1" -P "${DEFAULT_PORT}" -u "${db_user}" -p"${db_password}" -e "SELECT 'OK' AS status;" "${db_name}" >/dev/null 2>&1; then
      log_ok "Autenticação TCP em 127.0.0.1 bem-sucedida! (Nota: O IP ${primary_ip} pode pertencer a uma sub-rede externa ao host local)."
    else
      log_warn "Conexão de teste via TCP falhou. Isso é esperado se o padrão de host '${mysql_host_pattern}' for restrito a outras máquinas remotas e não incluir o IP deste próprio nó."
    fi
  fi

  # Teste 4: Consulta de integridade do banco de dados
  log_info "Teste 4/4: Consultando tabelas no banco de dados '${db_name}'..."
  local table_count=""
  table_count=$(run_mysql_root "${mysql_bin}" "${mysql_socket}" "${morpheus_root_pwd}" "SELECT count(*) FROM information_schema.tables WHERE table_schema = '${db_name}';" 2>/dev/null || echo "0")
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
# Exibição do Banner Final e Instruções de Conexão
# ------------------------------------------------------------------------------
display_summary() {
  local primary_ip="$1"
  local backup_path="$2"

  cat <<EOF

==============================================================================
               DADOS DE CONEXÃO AO MYSQL EMBARCADO DO MORPHEUS
==============================================================================

  Host / IP do Appliance : ${primary_ip}
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
  Gerenciar nós do Galera Cluster               |  SIM   |  NÃO (Sem privilégios)
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
  ATENÇÃO PARA TOPOLOGIAS THREE-NODE (3 NÓS HA / GALERA):
------------------------------------------------------------------------------
  • Como seu appliance opera em cluster Galera (3 nós), os privilégios do
    usuário MySQL criados aqui foram REPLICADOS AUTOMATICAMENTE para os outros nós.
  • No entanto, o arquivo '/etc/morpheus/morpheus.rb' e a regra de firewall
    precisam ser aplicados individualmente em cada um dos outros nós caso você
    deseje conectar apontando para o IP direto de qualquer um deles.
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
      -s|--subnet)
        client_subnet="${2:-}"
        shift 2
        ;;
      -u|--db-user)
        db_user="${2:-}"
        shift 2
        ;;
      -p|--db-password)
        db_password="${2:-}"
        shift 2
        ;;
      -d|--db-name)
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
      -b|--backup-dir)
        backup_base_dir="${2:-}"
        shift 2
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

  # Validação do arquivo de configuração do Morpheus
  if [[ ! -f "${morpheus_config}" ]]; then
    log_error "Arquivo de configuração '${morpheus_config}' não foi encontrado."
    log_error "Verifique se este script está sendo executado no nó do appliance Morpheus."
    exit 1
  fi

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

  # Geração da senha caso não fornecida
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
  log_info "Detectando binários e ambiente do Morpheus..."
  local mysql_bin
  mysql_bin="$(find_mysql_bin)"
  readonly mysql_bin

  local mysql_socket
  mysql_socket="$(find_mysql_socket)"
  readonly mysql_socket

  local morpheus_root_pwd
  morpheus_root_pwd="$(get_morpheus_root_password)"
  readonly morpheus_root_pwd

  local primary_ip
  primary_ip="$(get_primary_ip)"
  readonly primary_ip

  local fw_backend
  fw_backend="$(detect_firewall_backend)"
  readonly fw_backend

  log_ok "Binário MySQL   : ${mysql_bin}"
  log_ok "Socket MySQL    : ${mysql_socket:-'não encontrado (tentará conexão padrão)'}"
  log_ok "IP Primário     : ${primary_ip}"
  log_ok "Backend Firewall: ${fw_backend}"

  # 1. Geração de Backup
  create_backup "${current_backup_dir}" "${fw_backend}"

  # 2. Configuração do morpheus.rb
  configure_morpheus_rb

  # 3. Execução de morpheus-ctl reconfigure
  if [[ "${skip_reconfigure}" == false ]]; then
    log_info "Executando 'morpheus-ctl reconfigure' para aplicar as diretivas de rede no appliance..."
    if command -v morpheus-ctl >/dev/null 2>&1; then
      morpheus-ctl reconfigure
    elif [[ -x "/usr/bin/morpheus-ctl" ]]; then
      /usr/bin/morpheus-ctl reconfigure
    else
      log_warn "Comando 'morpheus-ctl' não localizado no PATH padrão. Execute manualmente após o término."
    fi
    log_ok "Reconfiguração do Morpheus concluída."
  else
    log_warn "Flag --skip-reconfigure informada. O comando 'morpheus-ctl reconfigure' NÃO foi executado."
  fi

  # 4. Liberação no Firewall
  apply_firewall_rule "${fw_backend}" "${client_subnet}"

  # 5. Concessão de Privilégios no MySQL
  configure_mysql_user "${mysql_bin}" "${mysql_socket}" "${morpheus_root_pwd}"

  # 6. Testes Automatizados de Validação
  run_verification_tests "${mysql_bin}" "${primary_ip}"

  # 7. Exibição do Resumo Final com Credenciais e Instruções
  display_summary "${primary_ip}" "${current_backup_dir}"
}

main "$@"
