#!/usr/bin/env bash
# ==============================================================================
# Script: extract-pfx.sh
# Descrição: Extrai chave privada, certificado e cadeia de CA de arquivos .pfx/.p12
#            para configuração direta de SSL/TLS no Nginx.
# Autor: DevOps Vanilla / BatOps
# ==============================================================================

set -euo pipefail

# Cores para exibição amigável
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Mensagens formatadas
log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCESSO]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[AVISO]${NC} $*"; }
log_error()   { echo -e "${RED}[ERRO]${NC} $*" >&2; }
log_step()    { echo -e "\n${BOLD}${CYAN}==>${NC} ${BOLD}$*${NC}"; }

# Variáveis padrão
PFX_FILE=""
OUTPUT_DIR=""
PFX_PASSWORD=""
PROMPT_PASSWORD=true
FORCE_LEGACY_ARG=false

usage() {
    cat <<EOF
Uso: $0 [OPÇÕES]

Extrai certificados e chaves de arquivos PFX/PKCS#12 prontos para uso no Nginx.

Opções:
  -f, --file <arquivo.pfx>     Caminho para o arquivo .pfx ou .p12
  -o, --output <diretório>     Diretório de destino (padrão: ./extracted_<nome>)
  -p, --password <senha>       Senha do arquivo PFX (se omitida, será solicitada de forma segura)
      --legacy                 Força o uso do provedor de cifras legadas do OpenSSL 3.x (-legacy)
  -h, --help                   Exibe esta ajuda

Exemplos:
  $0
  $0 -f meu-certificado.pfx
  $0 -f meu-certificado.pfx -o /etc/nginx/ssl/meudominio -p "MinhaSenha123"
  $0 -f certificado_antigo_iis.pfx --legacy

EOF
    exit 0
}

# Parse de argumentos
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file)
            PFX_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -p|--password)
            PFX_PASSWORD="$2"
            PROMPT_PASSWORD=false
            shift 2
            ;;
        --legacy)
            FORCE_LEGACY_ARG=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Opção desconhecida: $1"
            usage
            ;;
    esac
done

# Verificação do OpenSSL
if ! command -v openssl &>/dev/null; then
    log_error "OpenSSL não encontrado no sistema. Instale com: sudo apt update && sudo apt install -y openssl"
    exit 1
fi

OPENSSL_VERSION=$(openssl version)
log_info "Versão do OpenSSL detectada: ${BOLD}${OPENSSL_VERSION}${NC}"

# Solicitação interativa do arquivo se não informado
if [[ -z "$PFX_FILE" ]]; then
    echo -e "${BOLD}Digite o caminho para o arquivo .pfx ou .p12:${NC}"
    read -r -e -p "> " PFX_FILE
fi

# Validação da existência do arquivo
if [[ ! -f "$PFX_FILE" ]]; then
    log_error "Arquivo '$PFX_FILE' não encontrado."
    exit 1
fi

# Define diretório de saída caso não informado
if [[ -z "$OUTPUT_DIR" ]]; then
    FILENAME=$(basename -- "$PFX_FILE")
    BASENAME="${FILENAME%.*}"
    OUTPUT_DIR="./extracted_${BASENAME}"
fi

# Solicitação segura de senha caso não informada
if [ "$PROMPT_PASSWORD" = true ]; then
    echo -e "${BOLD}Digite a senha do arquivo PFX (deixe em branco se não houver senha):${NC}"
    read -s -r -p "> " PFX_PASSWORD
    echo ""
fi

# Arquivo temporário seguro para passar senha sem expor no ps/history
PASS_TMP=$(mktemp)
echo -n "$PFX_PASSWORD" > "$PASS_TMP"
cleanup() {
    rm -f "$PASS_TMP"
}
trap cleanup EXIT

# Testar se precisa de -legacy (comum no OpenSSL 3 com PFX do Windows IIS / RC2 / 3DES)
test_pfx_reading() {
    local legacy_flag="$1"
    if [[ -n "$legacy_flag" ]]; then
        openssl pkcs12 -in "$PFX_FILE" -passin "file:$PASS_TMP" -nokeys -legacy >/dev/null 2>&1
    else
        openssl pkcs12 -in "$PFX_FILE" -passin "file:$PASS_TMP" -nokeys >/dev/null 2>&1
    fi
}

log_step "Validando arquivo e senha do PFX..."

EXTRA_ARGS=()
if [ "$FORCE_LEGACY_ARG" = true ]; then
    log_info "Forçando flag '-legacy' conforme solicitado via argumento."
    EXTRA_ARGS+=("-legacy")
else
    # Tenta leitura padrão
    if test_pfx_reading ""; then
        log_info "PFX acessível usando provedores padrão do OpenSSL."
    else
        # Se falhou, pode ser senha incorreta OU necessidade do provedor legacy (OpenSSL 3+)
        if test_pfx_reading "-legacy"; then
            log_warn "O arquivo PFX utiliza algoritmos criptográficos legados (ex: RC2/3DES comum no Windows/IIS)."
            log_warn "Ativando suporte ao provedor '-legacy' do OpenSSL 3 automaticamente."
            EXTRA_ARGS+=("-legacy")
        else
            log_error "Falha ao ler o PFX. Causas possíveis:"
            log_error " 1. A senha informada está incorreta."
            log_error " 2. O arquivo está corrompido ou em formato inválido."
            exit 1
        fi
    fi
fi

# Cria diretório de destino
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR_ABS=$(cd "$OUTPUT_DIR" && pwd)
log_info "Diretório de saída: ${BOLD}${OUTPUT_DIR_ABS}${NC}"

# Nomes dos arquivos de saída
KEY_FILE="${OUTPUT_DIR_ABS}/privkey.key"
CERT_FILE="${OUTPUT_DIR_ABS}/cert.crt"
CHAIN_FILE="${OUTPUT_DIR_ABS}/chain.crt"
FULLCHAIN_FILE="${OUTPUT_DIR_ABS}/fullchain.crt"
INFO_FILE="${OUTPUT_DIR_ABS}/cert-info.txt"
NGINX_CONF_FILE="${OUTPUT_DIR_ABS}/nginx-ssl-sample.conf"

# ------------------------------------------------------------------------------
# 1. Extração da Chave Privada (sem senha para o Nginx não travar no boot/reload)
# ------------------------------------------------------------------------------
log_step "1/4 Extraindo Chave Privada (descriptografada para Nginx)..."
if openssl pkcs12 -in "$PFX_FILE" \
    -passin "file:$PASS_TMP" \
    -nocerts -nodes \
    "${EXTRA_ARGS[@]}" \
    -out "$KEY_FILE" 2>/dev/null; then

    # Define permissões estritas para a chave privada (apenas o dono pode ler)
    chmod 600 "$KEY_FILE"
    log_success "Chave privada extraída com sucesso: $KEY_FILE (chmod 600)"
else
    log_error "Erro ao extrair chave privada do arquivo PFX."
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. Extração do Certificado do Servidor (Leaf / Client Certificate)
# ------------------------------------------------------------------------------
log_step "2/4 Extraindo Certificado do Servidor (Leaf)..."
if openssl pkcs12 -in "$PFX_FILE" \
    -passin "file:$PASS_TMP" \
    -clcerts -nokeys \
    "${EXTRA_ARGS[@]}" \
    -out "$CERT_FILE" 2>/dev/null; then
    chmod 644 "$CERT_FILE"
    log_success "Certificado do servidor extraído: $CERT_FILE"
else
    log_error "Erro ao extrair o certificado do servidor."
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. Extração da Cadeia de Certificados das Autoridades Certificadoras (CA Chain)
# ------------------------------------------------------------------------------
log_step "3/4 Extraindo Cadeia de Certificados Intermediários (CA Chain)..."
if openssl pkcs12 -in "$PFX_FILE" \
    -passin "file:$PASS_TMP" \
    -cacerts -nokeys \
    "${EXTRA_ARGS[@]}" \
    -out "$CHAIN_FILE" 2>/dev/null; then
    chmod 644 "$CHAIN_FILE"

    # Verifica se o arquivo tem conteúdo real de certificado
    if grep -q "BEGIN CERTIFICATE" "$CHAIN_FILE"; then
        log_success "Cadeia de CA extraída: $CHAIN_FILE"
    else
        log_warn "Nenhum certificado intermediário/CA encontrado no interior do PFX."
        log_warn "O arquivo chain.crt ficou vazio. Caso sua AC exija intermediários, forneça-os separadamente."
    fi
else
    log_warn "Não foi possível extrair certificados de CA intermediários."
    touch "$CHAIN_FILE"
fi

# ------------------------------------------------------------------------------
# 4. Geração do Fullchain para Nginx (Leaf + Intermediárias na ordem exigida)
# ------------------------------------------------------------------------------
log_step "4/4 Montando arquivo fullchain.crt para o Nginx..."
# Ordem exigida pelo Nginx e RFC: Primeiro o certificado do domínio, depois as intermediárias
if [ -s "$CHAIN_FILE" ] && grep -q "BEGIN CERTIFICATE" "$CHAIN_FILE"; then
    cat "$CERT_FILE" "$CHAIN_FILE" > "$FULLCHAIN_FILE"
    log_info "Combinando certificado do domínio + certificados intermediários em fullchain.crt."
else
    cp "$CERT_FILE" "$FULLCHAIN_FILE"
    log_info "Cadeia intermediária ausente no PFX; fullchain.crt criado contendo apenas o certificado do domínio."
fi
chmod 644 "$FULLCHAIN_FILE"
log_success "Arquivo fullchain gerado com sucesso: $FULLCHAIN_FILE"

# ------------------------------------------------------------------------------
# 5. Validação de Integridade: Comparar chave pública do Certificado e da Key
# ------------------------------------------------------------------------------
log_step "Verificando correspondência entre chave privada e certificado..."

PUBKEY_CERT_HASH=$(openssl x509 -in "$CERT_FILE" -noout -pubkey | openssl sha256 | awk '{print $NF}')
PUBKEY_KEY_HASH=$(openssl pkey -in "$KEY_FILE" -pubout 2>/dev/null | openssl sha256 | awk '{print $NF}')

if [[ "$PUBKEY_CERT_HASH" == "$PUBKEY_KEY_HASH" ]]; then
    log_success "Chave privada e Certificado CORRESPONDEM perfeitamente! (SHA256 da chave pública: ${PUBKEY_CERT_HASH:0:16}...)"
else
    log_error "DIVERGÊNCIA DETECTADA! A chave privada extraída NÃO corresponde ao certificado do servidor!"
    log_error "Hash pública Cert: $PUBKEY_CERT_HASH"
    log_error "Hash pública Key:  $PUBKEY_KEY_HASH"
    log_error "Não utilize estes arquivos no Nginx, pois a inicialização irá falhar com erro de 'key values mismatch'."
    exit 1
fi

# ------------------------------------------------------------------------------
# 6. Extração de Metadados e Informações Úteis (cert-info.txt)
# ------------------------------------------------------------------------------
SUBJECT=$(openssl x509 -in "$CERT_FILE" -noout -subject | sed 's/^subject=//')
ISSUER=$(openssl x509 -in "$CERT_FILE" -noout -issuer | sed 's/^issuer=//')
NOT_BEFORE=$(openssl x509 -in "$CERT_FILE" -noout -startdate | cut -d= -f2)
NOT_AFTER=$(openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)
SANS=$(openssl x509 -in "$CERT_FILE" -noout -ext subjectAltName 2>/dev/null | grep -v "X509v3" | sed 's/^[ \t]*//' || echo "Nenhum SAN")
FINGERPRINT=$(openssl x509 -in "$CERT_FILE" -noout -fingerprint -sha256)

# Teste de expiração
if openssl x509 -checkend 0 -noout -in "$CERT_FILE" >/dev/null 2>&1; then
    DAYS_LEFT=$(( ($(date -d "$NOT_AFTER" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$NOT_AFTER" +%s 2>/dev/null || echo 0) - $(date +%s)) / 86400 ))
    if [ "$DAYS_LEFT" -gt 0 ]; then
        STATUS_EXPIRATION_PLAIN="Válido (expira em aproximadamente ${DAYS_LEFT} dias)"
        STATUS_EXPIRATION_CONSOLE="${GREEN}${STATUS_EXPIRATION_PLAIN}${NC}"
    else
        STATUS_EXPIRATION_PLAIN="Válido (expira hoje)"
        STATUS_EXPIRATION_CONSOLE="${YELLOW}${STATUS_EXPIRATION_PLAIN}${NC}"
    fi
else
    STATUS_EXPIRATION_PLAIN="EXPIRADO!"
    STATUS_EXPIRATION_CONSOLE="${RED}${STATUS_EXPIRATION_PLAIN}${NC}"
fi

cat <<EOF > "$INFO_FILE"
================================================================================
                    INFORMAÇÕES DO CERTIFICADO SSL
================================================================================
Arquivo PFX Origem: $PFX_FILE
Data da Extração:   $(date)

[Assunto / Subject]
$SUBJECT

[Emissor / Issuer]
$ISSUER

[Nomes Alternativos / SANs]
$SANS

[Período de Validade]
Início (Not Before): $NOT_BEFORE
Fim    (Not After):  $NOT_AFTER
Status:              $STATUS_EXPIRATION_PLAIN

[Fingerprint SHA-256]
$FINGERPRINT

[Validação de Chave]
SHA256 PubKey Match: $PUBKEY_CERT_HASH
================================================================================
EOF
chmod 644 "$INFO_FILE"

# ------------------------------------------------------------------------------
# 7. Gerar Bloco de Configuração de Exemplo para Nginx
# ------------------------------------------------------------------------------
cat <<EOF > "$NGINX_CONF_FILE"
# ==============================================================================
# Exemplo de configuração de VirtualHost SSL para Nginx
# Copie ou adapte este bloco dentro do arquivo /etc/nginx/conf.d/ ou /etc/nginx/sites-available/
# ==============================================================================

server {
    listen 80;
    listen [::]:80;
    server_name seudominio.com.br www.seudominio.com.br;

    # Redirecionamento forçado para HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name seudominio.com.br www.seudominio.com.br;

    # Certificados extraídos pelo script:
    ssl_certificate         ${FULLCHAIN_FILE};
    ssl_certificate_key     ${KEY_FILE};

    # Opcional (se tiver OCSP Stapling configurado):
    # ssl_trusted_certificate ${CHAIN_FILE};
    # ssl_stapling on;
    # ssl_stapling_verify on;

    # Parâmetros de segurança modernos recomendados:
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;

    # Cabeçalhos de Segurança (HSTS)
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Raiz da aplicação ou Proxy reverso
    location / {
        # Exemplo proxy:
        # proxy_pass http://127.0.0.1:3000;
        # proxy_set_header Host \$host;
        # proxy_set_header X-Real-IP \$remote_addr;
        # proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        # proxy_set_header X-Forwarded-Proto \$scheme;

        # Exemplo estático:
        root /var/www/html;
        index index.html index.htm;
    }
}
EOF
chmod 644 "$NGINX_CONF_FILE"

# ------------------------------------------------------------------------------
# Resumo Final
# ------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}${GREEN}========================================================================${NC}"
echo -e "${BOLD}${GREEN}                   EXTRAÇÃO CONCLUÍDA COM SUCESSO!                      ${NC}"
echo -e "${BOLD}${GREEN}========================================================================${NC}"
echo -e "Todos os arquivos foram gerados no diretório: ${BOLD}${OUTPUT_DIR_ABS}${NC}\n"
echo -e "  📄 ${BOLD}privkey.key${NC}           -> Chave privada sem senha (permissão 600)"
echo -e "  📄 ${BOLD}cert.crt${NC}              -> Certificado do domínio / servidor (leaf)"
echo -e "  📄 ${BOLD}chain.crt${NC}             -> Certificado(s) da(s) AC(s) intermediária(s)"
echo -e "  ⭐ ${BOLD}fullchain.crt${NC}         -> ${CYAN}Use este na diretiva ssl_certificate do Nginx!${NC}"
echo -e "  📋 ${BOLD}cert-info.txt${NC}         -> Resumo dos metadados e validade"
echo -e "  🛠️  ${BOLD}nginx-ssl-sample.conf${NC} -> Exemplo de configuração pronto para uso\n"

echo -e "${BOLD}Resumo do Certificado:${NC}"
echo -e "  • Assunto:  ${CYAN}${SUBJECT}${NC}"
echo -e "  • Emissor:  ${CYAN}${ISSUER}${NC}"
echo -e "  • Validade: ${STATUS_EXPIRATION_CONSOLE}"
echo -e "  • SANs:     ${SANS}"
echo ""
echo -e "${BOLD}Como aplicar no Nginx:${NC}"
echo -e "  1. Copie os arquivos para o diretório SSL do seu servidor (ex: /etc/nginx/ssl/):"
echo -e "     ${YELLOW}sudo cp ${FULLCHAIN_FILE} ${KEY_FILE} /etc/nginx/ssl/${NC}"
echo -e "  2. No seu arquivo de configuração do Nginx, aponte:"
echo -e "     ${YELLOW}ssl_certificate     /etc/nginx/ssl/fullchain.crt;${NC}"
echo -e "     ${YELLOW}ssl_certificate_key /etc/nginx/ssl/privkey.key;${NC}"
echo -e "  3. Valide a sintaxe do Nginx:"
echo -e "     ${YELLOW}sudo nginx -t${NC}"
echo -e "  4. Recarregue o Nginx:"
echo -e "     ${YELLOW}sudo systemctl reload nginx${NC}\n"
