#!/bin/bash

###############################################################################
# Script: setup-portainer.sh
# Descrição: Configura o ambiente para executar Portainer com DNS customizado
# Uso: ./setup-portainer.sh
###############################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Diretório de scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Setup Portainer com DNS Customizado           ║${NC}"
echo -e "${BLUE}║  Host: portainer.local                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Verificar Docker
echo -e "${YELLOW}[*]${NC} Verificando Docker..."
if ! command -v docker &> /dev/null; then
    echo -e "${RED}[✗]${NC} Docker não encontrado. Por favor, instale o Docker."
    exit 1
fi
echo -e "${GREEN}[✓]${NC} Docker encontrado: $(docker --version)"

# Verificar Docker Compose
echo -e "${YELLOW}[*]${NC} Verificando Docker Compose..."
if ! docker compose version &> /dev/null 2>&1 && ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}[✗]${NC} Docker Compose não encontrado."
    exit 1
fi
echo -e "${GREEN}[✓]${NC} Docker Compose encontrado"

# Verificar OpenSSL
echo -e "${YELLOW}[*]${NC} Verificando OpenSSL..."
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}[✗]${NC} OpenSSL não encontrado."
    exit 1
fi
echo -e "${GREEN}[✓]${NC} OpenSSL encontrado: $(openssl version)"

echo ""
echo -e "${BLUE}Configurações Detectadas:${NC}"
echo "  Diretório: $SCRIPT_DIR"
echo "  WSL Hostname: $(hostname)"
echo "  WSL IP Local: $(hostname -I | awk '{print $1}')"

echo ""
echo -e "${YELLOW}[*]${NC} Gerando certificados auto-assinados..."
bash "$SCRIPT_DIR/generate-certificates.sh"

echo ""
echo -e "${YELLOW}[*]${NC} Ajustando permissões de arquivos..."
chmod 644 "$SCRIPT_DIR/certs/portainer.crt"
chmod 600 "$SCRIPT_DIR/certs/portainer.key"

echo ""
echo -e "${YELLOW}[*]${NC} Criando diretórios necessários..."
mkdir -p "$SCRIPT_DIR/data"

echo ""
echo -e "${GREEN}[✓]${NC} Setup concluído com sucesso!"
echo ""
echo -e "${BLUE}Próximos Passos:${NC}"
echo ""
echo "  1. Para iniciar o Portainer:"
echo "     bash $SCRIPT_DIR/run-portainer.sh"
echo ""
echo "  2. Para acessar no Windows:"
echo "     - Adicione ao hosts do Windows (C:\\Windows\\System32\\drivers\\etc\\hosts):"
echo "       127.0.0.1 portainer.local"
echo "     - Ou execute: bash $SCRIPT_DIR/add-to-windows-hosts.sh"
echo ""
echo "  3. Acesse: https://portainer.local"
echo ""
echo -e "${YELLOW}[!]${NC} IMPORTANTE: Configure o DNS para resolver portainer.local"
echo "     (consulte a documentação em README.md)"
echo ""
