#!/bin/bash
# setup-remote-docker.sh: Configura cliente para acessar Docker remoto via TLS
# Uso: ./setup-remote-docker.sh

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Diretórios
DOCKER_CERTS_DIR="$HOME/.docker/certs"
DOCKER_CONFIG_DIR="$HOME/.docker"
BASHRC="$HOME/.bashrc"
ZSHRC="$HOME/.zshrc"

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
        local remote_host=$(read_existing_config)
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
    
    # Remover variáveis de ambiente do shell config
    for rc in "$BASHRC" "$ZSHRC"; do
        if [ -f "$rc" ]; then
            sed -i '/# Docker Remote Configuration/d' "$rc"
            sed -i '/export DOCKER_HOST=/d' "$rc"
            sed -i '/export DOCKER_TLS_VERIFY=/d' "$rc"
            sed -i '/export DOCKER_CERT_PATH=/d' "$rc"
        fi
    done
    
    # Limpar variáveis da sessão atual
    unset DOCKER_HOST
    unset DOCKER_TLS_VERIFY
    unset DOCKER_CERT_PATH
    
    log "Docker local configurado."
    info "Faça logout/login ou execute: source ~/.bashrc"
}

# Função para usar Docker remoto
use_remote_docker() {
    local remote_host=$1
    
    log "Configurando para usar Docker remoto: $remote_host..."
    
    # Verificar se certificados existem
    if [ ! -d "$DOCKER_CERTS_DIR" ] || [ ! -f "$DOCKER_CERTS_DIR/ca.pem" ]; then
        error "Certificados não encontrados em $DOCKER_CERTS_DIR"
        error "Execute a configuração completa primeiro."
        exit 1
    fi
    
    # Configurar variáveis de ambiente
    configure_environment "$remote_host"
    
    log "Docker remoto configurado: $remote_host"
    info "Faça logout/login ou execute: source ~/.bashrc"
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
    
    # Solicitar usuário SSH (opcional)
    echo -n "Digite o usuário SSH do servidor [$USER]: "
    read -r SSH_USER
    SSH_USER=${SSH_USER:-$USER}
    
    # Testar conectividade
    log "Testando conectividade com $DOCKER_HOST_IP..."
    if ! ping -c 1 -W 2 "$DOCKER_HOST_IP" &>/dev/null; then
        warn "Não foi possível pingar o servidor. Continuando mesmo assim..."
    else
        log "Servidor acessível."
    fi
    
    # Criar diretório para certificados
    mkdir -p "$DOCKER_CERTS_DIR"
    
    # Copiar certificados do servidor
    log "Copiando certificados do servidor..."
    info "Você precisará fornecer a senha SSH do servidor."
    
    if scp -r "${SSH_USER}@${DOCKER_HOST_IP}:~/docker-client-certs/*" "$DOCKER_CERTS_DIR/" 2>/dev/null; then
        log "Certificados copiados com sucesso."
    else
        error "Falha ao copiar certificados."
        echo ""
        warn "Certifique-se de que:"
        info "  1. O servidor está acessível via SSH"
        info "  2. Os certificados estão em ~/docker-client-certs/ no servidor"
        info "  3. O script install-docker.sh foi executado no servidor"
        echo ""
        error "Execute 'ssh ${SSH_USER}@${DOCKER_HOST_IP} ls ~/docker-client-certs/' para verificar"
        exit 1
    fi
    
    # Ajustar permissões dos certificados
    chmod 0400 "$DOCKER_CERTS_DIR/key.pem"
    chmod 0444 "$DOCKER_CERTS_DIR/ca.pem" "$DOCKER_CERTS_DIR/cert.pem"
    
    log "Permissões dos certificados ajustadas."
    
    # Salvar configuração
    cat > "$DOCKER_CONFIG_DIR/remote-docker-host.conf" <<EOF
# Configuração do Docker Remoto
REMOTE_DOCKER_HOST=$DOCKER_HOST_IP
REMOTE_DOCKER_PORT=2376
REMOTE_DOCKER_USER=$SSH_USER
EOF
    
    # Configurar variáveis de ambiente
    configure_environment "$DOCKER_HOST_IP"
    
    # Testar conexão
    log "Testando conexão com Docker remoto..."
    if docker --tlsverify \
        --tlscacert="$DOCKER_CERTS_DIR/ca.pem" \
        --tlscert="$DOCKER_CERTS_DIR/cert.pem" \
        --tlskey="$DOCKER_CERTS_DIR/key.pem" \
        -H="tcp://$DOCKER_HOST_IP:2376" \
        version &>/dev/null; then
        log "✓ Conexão com Docker remoto bem-sucedida!"
        echo ""
        docker --tlsverify \
            --tlscacert="$DOCKER_CERTS_DIR/ca.pem" \
            --tlscert="$DOCKER_CERTS_DIR/cert.pem" \
            --tlskey="$DOCKER_CERTS_DIR/key.pem" \
            -H="tcp://$DOCKER_HOST_IP:2376" \
            version
    else
        error "Falha ao conectar ao Docker remoto."
        error "Verifique se o Docker está rodando no servidor e se a porta 2376 está acessível."
        exit 1
    fi
    
    echo ""
    log "Configuração concluída com sucesso!"
}

# Função para configurar variáveis de ambiente
configure_environment() {
    local host_ip=$1
    
    # Determinar qual shell config usar
    local shell_config=""
    if [ -n "$BASH_VERSION" ] && [ -f "$BASHRC" ]; then
        shell_config="$BASHRC"
    elif [ -n "$ZSH_VERSION" ] && [ -f "$ZSHRC" ]; then
        shell_config="$ZSHRC"
    else
        shell_config="$BASHRC"
    fi
    
    # Remover configurações antigas
    if [ -f "$shell_config" ]; then
        sed -i '/# Docker Remote Configuration/d' "$shell_config"
        sed -i '/export DOCKER_HOST=/d' "$shell_config"
        sed -i '/export DOCKER_TLS_VERIFY=/d' "$shell_config"
        sed -i '/export DOCKER_CERT_PATH=/d' "$shell_config"
    fi
    
    # Adicionar novas configurações
    cat >> "$shell_config" <<EOF

# Docker Remote Configuration
export DOCKER_HOST=tcp://${host_ip}:2376
export DOCKER_TLS_VERIFY=1
export DOCKER_CERT_PATH=$DOCKER_CERTS_DIR
EOF
    
    log "Variáveis de ambiente configuradas em $shell_config"
    
    # Configurar para a sessão atual
    export DOCKER_HOST="tcp://${host_ip}:2376"
    export DOCKER_TLS_VERIFY=1
    export DOCKER_CERT_PATH="$DOCKER_CERTS_DIR"
}

# Banner
echo ""
echo "================================================="
echo "   Configuração de Docker Remoto com TLS"
echo "================================================="
echo ""

# Executar verificações e configuração
check_requirements
choose_docker_mode

# Instruções finais
echo ""
echo "================================================="
log "Configuração finalizada!"
echo "================================================="
echo ""
info "Para aplicar as alterações:"
echo "  source ~/.bashrc"
echo ""
info "Para testar a conexão:"
echo "  docker ps"
echo "  docker info"
echo ""
info "Para criar um context Docker (recomendado):"
echo "  docker context create remote --docker \"host=tcp://$DOCKER_HOST_IP:2376,ca=$DOCKER_CERTS_DIR/ca.pem,cert=$DOCKER_CERTS_DIR/cert.pem,key=$DOCKER_CERTS_DIR/key.pem\""
echo "  docker context use remote"
echo ""
info "Para voltar ao Docker local (se disponível):"
echo "  Execute este script novamente e escolha a opção 'Docker Local'"
echo "================================================="
