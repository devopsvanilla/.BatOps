#!/bin/bash
# install-docker.sh: Instala e configura Docker no Ubuntu para uso como host remoto com TLS
# Uso: sudo ./install-docker.sh

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Diretório para certificados
CERT_DIR="/etc/docker/certs"
CLIENT_CERT_DIR="$HOME/docker-client-certs"

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
    sudo chown -R "$USER:$USER" "$CLIENT_CERT_DIR"
    chmod 0400 "$CLIENT_CERT_DIR/key.pem"
    chmod 0444 "$CLIENT_CERT_DIR/ca.pem" "$CLIENT_CERT_DIR/cert.pem"
    
    log "Certificados do cliente salvos em: $CLIENT_CERT_DIR"
}

# Verificar requisitos
check_requirements

# Detectar informações do host
detect_host_info

log "Atualizando lista de pacotes..."
sudo apt-get update

log "Instalando dependências do Docker..."
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

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

log "Adicionando usuário atual ao grupo docker..."
sudo usermod -aG docker "$USER"

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

# Aguardar o Docker iniciar
sleep 3

log "Configurando firewall para liberar porta 2376 (TLS)..."
sudo ufw allow 2376/tcp 2>/dev/null || warn "UFW não está ativo. Configure o firewall manualmente se necessário."

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
