#!/bin/bash
# setup-docker-remote.sh: Configura cliente para acessar Docker remoto via TLS usando Docker Contexts
# EXECUTE ESTE SCRIPT NO COMPUTADOR CLIENTE (que deseja usar Docker remoto)
# Uso: ./setup-docker-remote.sh

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Diretórios
DOCKER_BASE_DIR="$HOME/docker"
DOCKER_CONFIG_DIR="$HOME/.docker"

# Constantes
REMOTE_CONTEXT_PREFIX="remote"

# Função para exibir mensagens
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

info() {
    echo -e "${BLUE}[DETALHE]${NC} $1"
}

prompt() {
    echo -e "${CYAN}[PERGUNTA]${NC} $1"
}

# Função para limpar variáveis de ambiente antigas
clean_old_env_vars() {
    local bashrc="$HOME/.bashrc"
    local zshrc="$HOME/.zshrc"
    
    # Remover variáveis de ambiente antigas dos arquivos de configuração
    for rc in "$bashrc" "$zshrc"; do
        if [ -f "$rc" ]; then
            if grep -q "DOCKER_HOST\|DOCKER_TLS_VERIFY\|DOCKER_CERT_PATH" "$rc" 2>/dev/null; then
                warn "Removendo variáveis de ambiente Docker antigas de $(basename "$rc")..."
                sed -i '/# Docker Remote Configuration/d' "$rc"
                sed -i '/export DOCKER_HOST=/d' "$rc"
                sed -i '/export DOCKER_TLS_VERIFY=/d' "$rc"
                sed -i '/export DOCKER_CERT_PATH=/d' "$rc"
            fi
        fi
    done
    
    # Limpar variáveis da sessão atual
    if [ -n "$DOCKER_HOST" ] || [ -n "$DOCKER_TLS_VERIFY" ] || [ -n "$DOCKER_CERT_PATH" ]; then
        warn "Limpando variáveis de ambiente Docker da sessão atual..."
        unset DOCKER_HOST
        unset DOCKER_TLS_VERIFY
        unset DOCKER_CERT_PATH
        info "Variáveis limpas. Se necessário, reinicie o terminal para aplicar completamente."
    fi
}

# Função para verificar requisitos
check_requirements() {
    log "Verificando requisitos do sistema..."
    
    local missing_packages=()
    local install_docker=false
    
    # Verificar pacotes necessários
    for pkg in openssl curl; do
        if ! command -v "$pkg" &> /dev/null; then
            missing_packages+=("$pkg")
        fi
    done
    
    # Verificar se Docker CLI está instalado
    if ! command -v docker &> /dev/null; then
        warn "Docker CLI não está instalado."
        echo -n "Deseja instalar o Docker CLI? (s/N): "
        read -r response
        if [[ "$response" =~ ^[Ss]$ ]]; then
            install_docker=true
        else
            error "Docker CLI é necessário para conectar ao servidor remoto."
            exit 1
        fi
    fi
    
    # Instalar pacotes faltantes
    if [ ${#missing_packages[@]} -gt 0 ] || [ "$install_docker" = true ]; then
        log "Instalando pacotes necessários..."
        
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            [ ${#missing_packages[@]} -gt 0 ] && sudo apt-get install -y "${missing_packages[@]}"
            
            if [ "$install_docker" = true ]; then
                # Instalar apenas Docker CLI (sem daemon)
                sudo apt-get install -y ca-certificates gnupg lsb-release
                sudo mkdir -p /etc/apt/keyrings
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
                echo \
                  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
                  $(lsb_release -cs) stable" | \
                  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                sudo apt-get update
                sudo apt-get install -y docker-ce-cli
            fi
        elif command -v yum &> /dev/null; then
            [ ${#missing_packages[@]} -gt 0 ] && sudo yum install -y "${missing_packages[@]}"
            [ "$install_docker" = true ] && sudo yum install -y docker-ce-cli
        else
            error "Gerenciador de pacotes não suportado. Instale manualmente: ${missing_packages[*]}"
            exit 1
        fi
    fi
    
    log "Todos os requisitos foram atendidos."
}

# Função para detectar Docker local
check_local_docker() {
    if systemctl is-active --quiet docker 2>/dev/null || docker info &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Função para listar contexts disponíveis
list_docker_contexts() {
    docker context ls --format "{{.Name}}" 2>/dev/null || echo ""
}

# Função para verificar se um context existe
context_exists() {
    local context_name=$1
    docker context inspect "$context_name" &>/dev/null
}

# Função para obter context atual
get_current_context() {
    docker context show 2>/dev/null || echo "default"
}

# Função para criar Docker Context remoto
create_remote_context() {
    local context_name=$1
    local host_ip=$2
    local certs_dir=$3
    
    log "Criando Docker Context: $context_name..."
    
    if context_exists "$context_name"; then
        warn "Context '$context_name' já existe. Removendo o antigo..."
        docker context rm -f "$context_name" &>/dev/null
    fi
    
    docker context create "$context_name" \
        --docker "host=tcp://${host_ip}:2376,ca=${certs_dir}/ca.pem,cert=${certs_dir}/cert.pem,key=${certs_dir}/key.pem" \
        --description "Docker remoto em ${host_ip}"
    
    log "Context '$context_name' criado com sucesso!"
}

# Função para trocar para um context
switch_context() {
    local context_name=$1
    
    if ! context_exists "$context_name"; then
        error "Context '$context_name' não existe."
        return 1
    fi
    
    docker context use "$context_name"
    log "Trocado para context: $context_name"
}

# Função para detectar configuração remota existente
check_existing_remote_config() {
    if [ -f "$DOCKER_CONFIG_DIR/remote-docker-host.conf" ]; then
        return 0
    else
        return 1
    fi
}

# Função para ler configuração existente
read_existing_config() {
    if [ -f "$DOCKER_CONFIG_DIR/remote-docker-host.conf" ]; then
        source "$DOCKER_CONFIG_DIR/remote-docker-host.conf"
        echo "$REMOTE_DOCKER_HOST"
    fi
}

# Função para escolher modo Docker
choose_docker_mode() {
    local has_local=false
    local has_remote=false
    
    if check_local_docker; then
        has_local=true
        info "Docker local detectado"
    fi
    
    if check_existing_remote_config; then
        has_remote=true
        local remote_host
        remote_host=$(read_existing_config)
        info "Configuração remota existente detectada: $remote_host"
    fi
    
    if [ "$has_local" = true ] && [ "$has_remote" = true ]; then
        echo ""
        prompt "Qual Docker você deseja usar?"
        echo "  1) Docker Local"
        echo "  2) Docker Remoto ($remote_host)"
        echo "  3) Configurar novo Docker Remoto"
        echo -n "Escolha (1/2/3): "
        read -r choice
        
        case $choice in
            1)
                use_local_docker
                exit 0
                ;;
            2)
                use_remote_docker "$remote_host"
                exit 0
                ;;
            3)
                setup_new_remote
                ;;
            *)
                error "Opção inválida"
                exit 1
                ;;
        esac
    elif [ "$has_local" = true ]; then
        echo ""
        prompt "Docker local detectado. Deseja configurar Docker remoto? (s/N): "
        read -r response
        if [[ "$response" =~ ^[Ss]$ ]]; then
            setup_new_remote
        else
            log "Usando Docker local."
            exit 0
        fi
    elif [ "$has_remote" = true ]; then
        echo ""
        prompt "Configuração remota existente: $remote_host"
        echo "  1) Usar configuração existente"
        echo "  2) Configurar novo servidor"
        echo -n "Escolha (1/2): "
        read -r choice
        
        case $choice in
            1)
                use_remote_docker "$remote_host"
                exit 0
                ;;
            2)
                setup_new_remote
                ;;
            *)
                error "Opção inválida"
                exit 1
                ;;
        esac
    else
        setup_new_remote
    fi
}

# Função para usar Docker local
use_local_docker() {
    log "Configurando para usar Docker local..."
    
    switch_context "default"
    
    log "✓ Docker local ativado!"
    info "Você já pode usar 'docker ps' para testar."
}

# Função para usar Docker remoto
use_remote_docker() {
    local remote_host=$1
    local context_name="${REMOTE_CONTEXT_PREFIX}-${remote_host}"
    local DOCKER_CERTS_DIR="$DOCKER_BASE_DIR/$remote_host/docker-client-certs"
    
    log "Configurando para usar Docker remoto: $remote_host..."
    
    # Verificar se certificados existem
    if [ ! -d "$DOCKER_CERTS_DIR" ] || [ ! -f "$DOCKER_CERTS_DIR/ca.pem" ]; then
        error "Certificados não encontrados em $DOCKER_CERTS_DIR"
        error "Execute a configuração completa primeiro."
        exit 1
    fi
    
    # Verificar se context existe, senão criar
    if ! context_exists "$context_name"; then
        create_remote_context "$context_name" "$remote_host" "$DOCKER_CERTS_DIR"
    fi
    
    # Trocar para o context remoto
    switch_context "$context_name"
    
    log "✓ Docker remoto ativado: $remote_host"
    info "Você já pode usar 'docker ps' para testar."
}

# Função para configurar novo servidor remoto
setup_new_remote() {
    echo ""
    log "Configurando novo servidor Docker remoto..."
    
    # Solicitar IP do servidor
    echo -n "Digite o IP do servidor Docker remoto: "
    read -r DOCKER_HOST_IP
    
    if [ -z "$DOCKER_HOST_IP" ]; then
        error "IP não pode estar vazio"
        exit 1
    fi
    
    # Validar formato de IP (básico)
    if ! [[ "$DOCKER_HOST_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        error "Formato de IP inválido"
        exit 1
    fi
    
    # Solicitar usuário SSH
    echo -n "Digite o usuário SSH do servidor [$USER]: "
    read -r SSH_USER
    SSH_USER=${SSH_USER:-$USER}
    
    # Solicitar senha SSH (opcional)
    echo ""
    info "Se você possui uma chave SSH configurada, apenas pressione ENTER para pular a senha."
    echo -n "Digite a senha SSH (ou ENTER para usar chave SSH): "
    read -rs SSH_PASSWORD
    echo ""
    
    # Testar conectividade
    log "Testando conectividade com $DOCKER_HOST_IP..."
    if ! ping -c 1 -W 2 "$DOCKER_HOST_IP" &>/dev/null; then
        warn "Não foi possível pingar o servidor. Continuando mesmo assim..."
    else
        log "Servidor acessível."
    fi
    
    # Criar diretório local para certificados
    local DOCKER_CERTS_DIR="$DOCKER_BASE_DIR/$DOCKER_HOST_IP/docker-client-certs"
    mkdir -p "$DOCKER_CERTS_DIR"
    
    # Copiar certificados do servidor
    log "Copiando certificados do servidor remoto..."
    
    if [ -n "$SSH_PASSWORD" ]; then
        # Usar sshpass se senha foi fornecida
        if ! command -v sshpass &> /dev/null; then
            warn "sshpass não está instalado. Tentando instalar..."
            if command -v apt-get &> /dev/null; then
                sudo apt-get install -y sshpass
            elif command -v yum &> /dev/null; then
                sudo yum install -y sshpass
            else
                error "Não foi possível instalar sshpass. Use chave SSH ou instale manualmente."
                exit 1
            fi
        fi
        
        if sshpass -p "$SSH_PASSWORD" scp -r "${SSH_USER}@${DOCKER_HOST_IP}:~/docker-client-certs/"* "$DOCKER_CERTS_DIR/" 2>/dev/null; then
            log "Certificados copiados com sucesso."
        else
            error "Falha ao copiar certificados com senha."
            error "Verifique a senha e tente novamente."
            exit 1
        fi
    else
        # Usar chave SSH
        info "Usando chave SSH para autenticação..."
        if scp -r "${SSH_USER}@${DOCKER_HOST_IP}:~/docker-client-certs/"* "$DOCKER_CERTS_DIR/" 2>/dev/null; then
            log "Certificados copiados com sucesso."
        else
            error "Falha ao copiar certificados."
            echo ""
            warn "Certifique-se de que:"
            info "  1. O servidor está acessível via SSH"
            info "  2. Os certificados estão em ~/docker-client-certs/ no servidor"
            info "  3. O script install-docker.sh foi executado no servidor"
            info "  4. Sua chave SSH está configurada corretamente"
            echo ""
            error "Execute 'ssh ${SSH_USER}@${DOCKER_HOST_IP} ls ~/docker-client-certs/' para verificar"
            exit 1
        fi
    fi
    
    # Ajustar permissões dos certificados
    chmod 0400 "$DOCKER_CERTS_DIR/key.pem"
    chmod 0444 "$DOCKER_CERTS_DIR/ca.pem" "$DOCKER_CERTS_DIR/cert.pem"
    
    log "Permissões dos certificados ajustadas."
    
    # Salvar configuração
    mkdir -p "$DOCKER_CONFIG_DIR"
    cat > "$DOCKER_CONFIG_DIR/remote-docker-host.conf" <<EOF
# Configuração do Docker Remoto
REMOTE_DOCKER_HOST=$DOCKER_HOST_IP
REMOTE_DOCKER_PORT=2376
REMOTE_DOCKER_USER=$SSH_USER
REMOTE_DOCKER_CERTS=$DOCKER_CERTS_DIR
EOF
    
    # Criar Docker Context
    local context_name="${REMOTE_CONTEXT_PREFIX}-${DOCKER_HOST_IP}"
    create_remote_context "$context_name" "$DOCKER_HOST_IP" "$DOCKER_CERTS_DIR"
    
    # Testar conexão trocando temporariamente de context
    log "Testando conexão com Docker remoto..."
    if switch_context "$context_name" && docker version &>/dev/null; then
        log "✓ Conexão com Docker remoto bem-sucedida!"
        echo ""
        docker version
    else
        error "Falha ao conectar ao Docker remoto."
        error "Verifique se o Docker está rodando no servidor e se a porta 2376 está acessível."
        # Voltar para context anterior
        docker context use default &>/dev/null || true
        exit 1
    fi
    
    echo ""
    log "Configuração concluída com sucesso!"
    info "Context Docker criado: $context_name"
    info "Você já pode usar 'docker ps' para testar."
}



# Banner
echo ""
echo "================================================="
echo "   Configuração de Docker Remoto com TLS"
echo "================================================="
echo ""

# Limpar variáveis de ambiente antigas
clean_old_env_vars

# Executar verificações e configuração
check_requirements
choose_docker_mode

# Instruções finais
echo ""
echo "================================================="
log "Configuração finalizada!"
echo "================================================="
echo ""
info "Contexts Docker disponíveis:"
docker context ls
echo ""
info "Para trocar entre Docker local e remoto:"
echo "  docker context use default        # Docker local"
echo "  docker context use remote-<IP>    # Docker remoto"
echo ""
info "Para testar a conexão:"
echo "  docker ps"
echo "  docker info"
echo ""
info "Para listar contexts:"
echo "  docker context ls"
echo ""
info "Para remover um context remoto:"
echo "  docker context rm remote-<IP>"
echo ""
info "Os certificados estão em:"
echo "  ~/docker/<IP_SERVIDOR>/docker-client-certs/"
echo "================================================="
