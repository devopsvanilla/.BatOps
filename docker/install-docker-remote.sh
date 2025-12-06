#!/bin/bash
# install-docker-remote.sh: Instala e configura Docker no Ubuntu para uso como host remoto com TLS
# EXECUTE ESTE SCRIPT NO SERVIDOR REMOTO (Host Docker)
# Uso: sudo ./install-docker-remote.sh

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para verificar se Docker está instalado
is_docker_installed() {
    if command -v docker >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Função para verificar se usuário está no grupo docker
is_user_in_docker_group() {
    if id -nG "$USER" | grep -qw "docker"; then
        return 0
    else
        return 1
    fi
}
# Diretório para certificados
CERT_DIR="/etc/docker/certs"
# Obter o usuário real (não root mesmo quando executado com sudo)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")
CLIENT_CERT_DIR="$REAL_HOME/docker-client-certs"
BUSYBOX_IMAGE="busybox:1.36.1"

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

ensure_supported_filesystem() {
    local target_dir="/var/lib/docker"
    local fs_type
    mkdir -p "$target_dir"
    fs_type=$(df -PT "$target_dir" 2>/dev/null | awk 'NR==2 {print $2}')
    case "$fs_type" in
        ext2|ext3|ext4|xfs|btrfs)
            log "Filesystem detectado em $target_dir: $fs_type (compatível)."
            ;;
        *)
            error "Filesystem '$fs_type' em $target_dir não suporta corretamente permissões POSIX.";
            error "Use um disco formatado em ext4/xfs ou reposicione /var/lib/docker antes de prosseguir."
            exit 1
            ;;
    esac
}

ensure_busybox_available() {
    if ! docker image inspect "$BUSYBOX_IMAGE" >/dev/null 2>&1; then
        log "Baixando imagem utilitária '$BUSYBOX_IMAGE' para testes futuros..."
        docker pull "$BUSYBOX_IMAGE" >/dev/null
    fi
}

validate_volume_permissions() {
    log "Validando possibilidade de aplicar chown 10001:0 em volumes Docker..."
    ensure_busybox_available
    local volume_name="batops-perm-test-$(date +%s)"
    docker volume create "$volume_name" >/dev/null
    if docker run --rm -v "$volume_name:/mnt" "$BUSYBOX_IMAGE" \
        sh -c "mkdir -p /mnt/probe && chown 10001:0 /mnt/probe" >/dev/null 2>&1; then
        log "Volume de teste aceitou chown sem erros."
    else
        docker volume rm "$volume_name" >/dev/null 2>&1 || true
        error "Falha ao ajustar permissões em volumes Docker. Verifique se o host usa filesystem Linux (ext4/xfs) e não monta volumes em NTFS/SMB."
        exit 1
    fi
    docker volume rm "$volume_name" >/dev/null 2>&1 || true
}

# Função para verificar requisitos
check_requirements() {
    log "Verificando requisitos do sistema..."
    
    local missing_packages=()
    
    # Verificar se é Ubuntu
    if [ ! -f /etc/lsb-release ]; then
        error "Este script é destinado ao Ubuntu."
        exit 1
    fi
    
    # Verificar pacotes necessários
    for pkg in curl ca-certificates gnupg lsb-release openssl; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            missing_packages+=("$pkg")
        fi
    done
    
    if [ ${#missing_packages[@]} -gt 0 ]; then
        warn "Pacotes necessários não instalados: ${missing_packages[*]}"
        echo -n "Deseja instalar os pacotes necessários? (s/N): "
        read -r response
        if [[ "$response" =~ ^[Ss]$ ]]; then
            log "Instalando pacotes necessários..."
            sudo apt-get update
            sudo apt-get install -y "${missing_packages[@]}"
        else
            error "Instalação cancelada. Instale os pacotes necessários e execute novamente."
            exit 1
        fi
    else
        log "Todos os requisitos foram atendidos."
    fi
}

# Função para detectar informações do host
detect_host_info() {
    HOSTNAME=$(hostname)
    HOST_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}')
    
    log "Informações do host detectadas:"
    info "  Hostname: $HOSTNAME"
    info "  IP: $HOST_IP"
}

# Função para gerar certificados TLS
generate_certificates() {
    log "Gerando certificados TLS auto-assinados..."
    
    sudo mkdir -p "$CERT_DIR"
    cd "$CERT_DIR"
    
    # Gerar chave privada da CA
    log "Criando Certificate Authority (CA)..."
    sudo openssl genrsa -aes256 -passout pass:docker-ca-pass -out ca-key.pem 4096
    
    # Gerar certificado da CA
    sudo openssl req -new -x509 -days 365 -key ca-key.pem -sha256 \
        -passin pass:docker-ca-pass \
        -out ca.pem \
        -subj "/C=BR/ST=State/L=City/O=DockerCA/CN=$HOSTNAME"
    
    # Gerar chave privada do servidor
    log "Criando certificado do servidor..."
    sudo openssl genrsa -out server-key.pem 4096
    
    # Gerar CSR do servidor
    sudo openssl req -subj "/CN=$HOSTNAME" -sha256 -new -key server-key.pem -out server.csr
    
    # Criar arquivo de extensões para incluir IP e hostname
    echo "subjectAltName = DNS:$HOSTNAME,IP:$HOST_IP,IP:127.0.0.1" | sudo tee extfile.cnf > /dev/null
    echo "extendedKeyUsage = serverAuth" | sudo tee -a extfile.cnf > /dev/null
    
    # Assinar certificado do servidor
    sudo openssl x509 -req -days 365 -sha256 \
        -in server.csr \
        -CA ca.pem \
        -CAkey ca-key.pem \
        -passin pass:docker-ca-pass \
        -CAcreateserial \
        -out server-cert.pem \
        -extfile extfile.cnf
    
    # Gerar chave privada do cliente
    log "Criando certificado do cliente..."
    sudo openssl genrsa -out key.pem 4096
    
    # Gerar CSR do cliente
    sudo openssl req -subj '/CN=client' -new -key key.pem -out client.csr
    
    # Criar arquivo de extensões do cliente
    echo "extendedKeyUsage = clientAuth" | sudo tee extfile-client.cnf > /dev/null
    
    # Assinar certificado do cliente
    sudo openssl x509 -req -days 365 -sha256 \
        -in client.csr \
        -CA ca.pem \
        -CAkey ca-key.pem \
        -passin pass:docker-ca-pass \
        -CAcreateserial \
        -out cert.pem \
        -extfile extfile-client.cnf
    
    # Remover arquivos temporários
    sudo rm -f client.csr server.csr extfile.cnf extfile-client.cnf
    
    # Ajustar permissões
    sudo chmod -v 0400 ca-key.pem key.pem server-key.pem
    sudo chmod -v 0444 ca.pem server-cert.pem cert.pem
    
    log "Certificados gerados com sucesso em $CERT_DIR"
}

# Função para copiar certificados do cliente
copy_client_certificates() {
    log "Copiando certificados do cliente para $CLIENT_CERT_DIR..."
    
    mkdir -p "$CLIENT_CERT_DIR"
    sudo cp "$CERT_DIR/ca.pem" "$CLIENT_CERT_DIR/"
    sudo cp "$CERT_DIR/cert.pem" "$CLIENT_CERT_DIR/"
    sudo cp "$CERT_DIR/key.pem" "$CLIENT_CERT_DIR/"
    sudo chown -R "$REAL_USER:$REAL_USER" "$CLIENT_CERT_DIR"
    chmod 0400 "$CLIENT_CERT_DIR/key.pem"
    chmod 0444 "$CLIENT_CERT_DIR/ca.pem" "$CLIENT_CERT_DIR/cert.pem"
    
    log "Certificados do cliente salvos em: $CLIENT_CERT_DIR"
}

# --- INÍCIO DO FLUXO PRINCIPAL ---

# Verificar se está sendo executado como root
if [[ "$EUID" -ne 0 ]]; then
    error "Este script deve ser executado com sudo"
    error "Use: sudo ./install-docker-remote.sh"
    exit 1
fi

if is_docker_installed; then
    warn "Docker já está instalado no sistema."
    echo -n "Deseja continuar apenas com a configuração para acesso remoto (TLS)? (s/N): "
    read -r docker_config_response
    if [[ ! "$docker_config_response" =~ ^[Ss]$ ]]; then
        log "Instalação/Configuração cancelada pelo usuário."
        exit 0
    fi
    log "Prosseguindo apenas com a configuração para acesso remoto..."
    # Detectar informações do host mesmo quando Docker já está instalado
    detect_host_info
else
    log "Docker não está instalado. Prosseguindo com a instalação..."
    # Detectar informações do host para nova instalação
    detect_host_info
fi

ensure_supported_filesystem

# Verificar requisitos
if ! is_docker_installed; then
    check_requirements

    log "Atualizando lista de pacotes..."
    sudo apt-get update

    log "Instalando dependências do Docker..."
    for pkg in ca-certificates curl gnupg lsb-release; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            warn "Pacote $pkg não está instalado. Deseja instalar? (s/N): "
            read -r pkg_response
            if [[ "$pkg_response" =~ ^[Ss]$ ]]; then
                sudo apt-get install -y "$pkg"
            else
                error "Instalação cancelada. Instale o pacote $pkg e execute novamente."
                exit 1
            fi
        fi
    done

    log "Adicionando repositório oficial do Docker..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    log "Atualizando lista de pacotes..."
    sudo apt-get update

    log "Instalando Docker Engine..."
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Garantir que o grupo docker existe
    if ! getent group docker >/dev/null; then
        log "Grupo docker não existe. Criando grupo..."
        sudo groupadd docker
    fi
    log "Adicionando usuário atual ao grupo docker..."
    sudo usermod -aG docker "$REAL_USER"
fi

# Gerar certificados TLS
generate_certificates

# Copiar certificados para o cliente
copy_client_certificates

log "Configurando Docker daemon para usar TLS..."
sudo mkdir -p /etc/docker

# Criar daemon.json
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2376"],
  "tls": true,
  "tlscacert": "$CERT_DIR/ca.pem",
  "tlscert": "$CERT_DIR/server-cert.pem",
  "tlskey": "$CERT_DIR/server-key.pem",
  "tlsverify": true
}
EOF

# Criar override para o systemd
log "Configurando systemd para Docker com TLS..."
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/override.conf > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --containerd=/run/containerd/containerd.sock
EOF

log "Habilitando e reiniciando serviço Docker..."
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl restart docker

validate_volume_permissions

# Aguardar o Docker iniciar
sleep 3

log "Configurando firewall para liberar porta 2376 (TLS)..."
sudo ufw allow 2376/tcp 2>/dev/null || warn "UFW não está ativo. Configure o firewall manualmente se necessário."

# --- Dockly ---

# Função para instalar nvm, node, npm e dockly
install_dockly() {
    log "Instalando requisitos para Dockly (nvm, node, npm)..."
    if ! command -v nvm >/dev/null 2>&1; then
        log "Instalando nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    else
        log "nvm já instalado."
    fi
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install node --latest-npm
    nvm use node
    log "Instalando Dockly..."
    npm install -g dockly
}

if command -v dockly >/dev/null 2>&1; then
    log "Dockly já está instalado."
else
    echo -n "Deseja instalar o Dockly (dashboard CLI para Docker)? (s/N): "
    read -r dockly_response
    if [[ "$dockly_response" =~ ^[Ss]$ ]]; then
        install_dockly
    else
        warn "Instalação do Dockly ignorada pelo usuário."
    fi
fi

echo -n "Deseja testar a instalação e funcionamento do Dockly agora? (s/N): "
read -r dockly_test_response
if [[ "$dockly_test_response" =~ ^[Ss]$ ]]; then
    log "Executando Dockly..."
    dockly
else
    log "Teste do Dockly ignorado pelo usuário."
fi

# Exibir instruções finais
echo ""
echo "========================================="
log "Instalação e configuração concluídas!"
echo "========================================="
echo ""
info "Docker configurado com TLS no host:"
info "  Hostname: $HOSTNAME"
info "  IP: $HOST_IP"
info "  Porta TLS: 2376"
echo ""
warn "IMPORTANTE: Para aplicar as permissões do grupo docker, faça logout e login novamente."
echo ""
log "Certificados do cliente estão em: $CLIENT_CERT_DIR"
info "Você precisará copiar estes 3 arquivos para o computador cliente:"
info "  - ca.pem"
info "  - cert.pem"
info "  - key.pem"
echo ""
log "Para conectar de outro computador, use:"
echo ""
echo "  export DOCKER_HOST=tcp://$HOST_IP:2376"
echo "  export DOCKER_TLS_VERIFY=1"
echo "  export DOCKER_CERT_PATH=/caminho/para/certificados"
echo "  docker ps"
echo ""
info "Ou usando o comando diretamente:"
echo ""
echo "  docker --tlsverify --tlscacert=ca.pem --tlscert=cert.pem --tlskey=key.pem -H=tcp://$HOST_IP:2376 ps"
echo ""
log "Consulte o arquivo install-docker.md para instruções detalhadas."
echo "========================================="
