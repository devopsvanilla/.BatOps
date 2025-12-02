#!/bin/bash

###############################################################################
# Script: generate-certificates.sh
# Descrição: Gera certificados SSL auto-assinados para Portainer
# Uso: ./generate-certificates.sh
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
CERTS_DIR="${SCRIPT_DIR}/certs"
DAYS_VALID=365

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Gerador de Certificados Auto-Assinados        ║${NC}"
echo -e "${BLUE}║  Para Portainer (portainer.local)              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Criar diretório de certificados se não existir
if [ ! -d "$CERTS_DIR" ]; then
    echo -e "${YELLOW}[*]${NC} Criando diretório de certificados: $CERTS_DIR"
    mkdir -p "$CERTS_DIR"
fi

# Verificar se os certificados já existem
if [ -f "$CERTS_DIR/portainer.crt" ] && [ -f "$CERTS_DIR/portainer.key" ]; then
    echo -e "${YELLOW}[!]${NC} Certificados já existem em $CERTS_DIR"
    read -p "Deseja regenerar? (s/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo -e "${GREEN}[✓]${NC} Abortado. Certificados existentes serão mantidos."
        exit 0
    fi
    rm -f "$CERTS_DIR/portainer.crt" "$CERTS_DIR/portainer.key"
    echo -e "${YELLOW}[*]${NC} Certificados antigos removidos."
fi

# Gerar chave privada
echo -e "${YELLOW}[*]${NC} Gerando chave privada RSA (4096 bits)..."
openssl genrsa -out "$CERTS_DIR/portainer.key" 4096 2>/dev/null

# Gerar certificado auto-assinado
echo -e "${YELLOW}[*]${NC} Gerando certificado auto-assinado..."
openssl req -new -x509 -days "$DAYS_VALID" \
    -key "$CERTS_DIR/portainer.key" \
    -out "$CERTS_DIR/portainer.crt" \
    -subj "/C=BR/ST=SP/L=Sao Paulo/O=DevOps/CN=portainer.local" \
    -addext "subjectAltName=DNS:portainer.local,DNS:*.portainer.local,IP:127.0.0.1" \
    2>/dev/null

# Verificar se foi bem-sucedido
if [ -f "$CERTS_DIR/portainer.crt" ] && [ -f "$CERTS_DIR/portainer.key" ]; then
    echo ""
    echo -e "${GREEN}[✓]${NC} Certificados gerados com sucesso!"
    echo ""
    echo -e "${BLUE}Informações do Certificado:${NC}"
    openssl x509 -in "$CERTS_DIR/portainer.crt" -noout -text | grep -A 2 "Subject:\|Issuer:\|Not Before\|Not After\|DNS:"
    echo ""
    echo -e "${BLUE}Localização dos Certificados:${NC}"
    echo "  Chave privada: $CERTS_DIR/portainer.key"
    echo "  Certificado:   $CERTS_DIR/portainer.crt"
    echo ""
    echo -e "${YELLOW}[!]${NC} IMPORTANTE:"
    echo "    1. Como é auto-assinado, você receberá um aviso de segurança no navegador"
    echo "    2. Adicione uma exceção de segurança no navegador ou clique em 'Avançado'"
    echo "    3. O certificado é válido por $DAYS_VALID dias"
    echo ""
    exit 0
else
    echo -e "${RED}[✗]${NC} Erro ao gerar certificados!"
    exit 1
fi
