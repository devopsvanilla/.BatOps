#!/bin/bash

###############################################################################
# Script: diagnose-portainer.sh
# Descrição: Diagnostica problemas com a configuração do Portainer
# Uso: ./diagnose-portainer.sh
###############################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Diagnóstico do Portainer                      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
}

check_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}[✓]${NC} $2"
    else
        echo -e "${RED}[✗]${NC} $2"
    fi
}

print_header
echo ""

# 1. Verificar Docker
echo -e "${BLUE}1. Verificando Docker:${NC}"
docker --version > /dev/null 2>&1
check_result $? "Docker instalado"

docker ps > /dev/null 2>&1
check_result $? "Docker daemon rodando"

echo ""

# 2. Verificar Docker Compose
echo -e "${BLUE}2. Verificando Docker Compose:${NC}"
docker compose version > /dev/null 2>&1
check_result $? "Docker Compose disponível"

echo ""

# 3. Verificar Certificados
echo -e "${BLUE}3. Verificando Certificados:${NC}"
[ -f "$SCRIPT_DIR/certs/portainer.crt" ]
check_result $? "Certificado público existe"

[ -f "$SCRIPT_DIR/certs/portainer.key" ]
check_result $? "Chave privada existe"

if [ -f "$SCRIPT_DIR/certs/portainer.crt" ]; then
    openssl x509 -in "$SCRIPT_DIR/certs/portainer.crt" -noout -checkend 0 > /dev/null 2>&1
    check_result $? "Certificado ainda é válido"
    
    echo ""
    echo "  Validade do certificado:"
    openssl x509 -in "$SCRIPT_DIR/certs/portainer.crt" -noout -dates | sed 's/^/    /'
fi

echo ""

# 4. Verificar Configurações
echo -e "${BLUE}4. Verificando Configurações:${NC}"
[ -f "$SCRIPT_DIR/docker-compose.yml" ]
check_result $? "docker-compose.yml existe"

[ -f "$SCRIPT_DIR/nginx.conf" ]
check_result $? "nginx.conf existe"

[ -d "$SCRIPT_DIR/data" ]
check_result $? "Diretório data existe"

echo ""

# 5. Verificar Containers
echo -e "${BLUE}5. Status dos Containers:${NC}"
cd "$SCRIPT_DIR"

if docker compose ps | grep -q "portainer"; then
    echo -e "${GREEN}[✓]${NC} Containers rodando:"
    docker compose ps | tail -n +2 | sed 's/^/    /'
else
    echo -e "${YELLOW}[!]${NC} Nenhum container ativo"
fi

echo ""

# 6. Verificar Conectividade
echo -e "${BLUE}6. Testando Conectividade:${NC}"

if command -v curl &> /dev/null; then
    curl -s -k https://127.0.0.1:443/ > /dev/null 2>&1
    check_result $? "Portainer HTTPS respondendo"
    
    curl -s http://127.0.0.1:80/ > /dev/null 2>&1
    check_result $? "Nginx HTTP respondendo"
else
    echo -e "${YELLOW}[!]${NC} curl não instalado, pulando testes de conectividade"
fi

echo ""

# 7. Verificar Portas
echo -e "${BLUE}7. Verificando Portas:${NC}"

check_port() {
    if netstat -tuln 2>/dev/null | grep -q ":$1 "; then
        echo -e "${GREEN}[✓]${NC} Porta $1 em uso"
    elif ss -tuln 2>/dev/null | grep -q ":$1 "; then
        echo -e "${GREEN}[✓]${NC} Porta $1 em uso"
    else
        echo -e "${YELLOW}[!]${NC} Porta $1 não detectada"
    fi
}

check_port "80"
check_port "443"
check_port "8000"
check_port "9443"
check_port "9000"

echo ""

# 8. Verificar Volumes
echo -e "${BLUE}8. Volumes Docker:${NC}"
docker volume ls | grep portainer || echo -e "${YELLOW}[!]${NC} Nenhum volume encontrado"

echo ""

# 9. Verificar Redes
echo -e "${BLUE}9. Redes Docker:${NC}"
docker network ls | grep portainer || echo -e "${YELLOW}[!]${NC} Nenhuma rede encontrada"

echo ""

# 10. Espaço em Disco
echo -e "${BLUE}10. Espaço em Disco:${NC}"
df -h "$SCRIPT_DIR" | tail -n 1 | awk '{print "    Usado: " $3 " / Disponível: " $4}'

echo ""

echo -e "${BLUE}Resumo:${NC}"
echo "  Portainer: https://portainer.local"
echo "  Diretório: $SCRIPT_DIR"
echo "  Docker Socket: /var/run/docker.sock"
echo ""

echo -e "${YELLOW}[!]${NC} Para resolver problemas, consulte:"
echo "    bash $SCRIPT_DIR/run-portainer.sh logs"
echo ""
