#!/bin/bash

# Verifica se o usuário passou uma URL
if [ -z "$1" ]; then
  echo "Uso: $0 <URL>"
  exit 1
fi

URL="$1"

# Validação da URL no formato http(s)://<fqdn>
if [[ ! "$URL" =~ ^https?://([a-zA-Z0-9.-]+\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(/.*)?$ ]]; then
  echo "Erro: URL inválida. Use o formato http(s)://<domínio> (ex: https://devopsvanilla.guru)"
  exit 2
fi

# Extrai o FQDN da URL
FQDN=$(echo "$URL" | sed -E 's|https?://([^/:]+).*|\1|')

# Gera timestamp
TIMESTAMP=$(date +"%Y%m%d%H%M")

# Cria pasta de resultados
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/zap-results"
mkdir -p "$RESULTS_DIR"

# Caminho do relatório
HTML_REPORT="${RESULTS_DIR}/${FQDN}-${TIMESTAMP}.html"
PDF_REPORT="${RESULTS_DIR}/${FQDN}-${TIMESTAMP}.pdf"

# Executa ZAP em modo baseline e gera relatório HTML
echo "🔍 Executando scan de segurança em: $URL"
docker run --rm -v "$RESULTS_DIR:/zap/wrk:rw" -t ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
  -t "$URL" \
  -r "$(basename "$HTML_REPORT")"

# Verifica se o relatório HTML foi gerado
if [ ! -f "$HTML_REPORT" ]; then
  echo "❌ Erro: Relatório HTML não foi gerado"
  exit 4
fi

echo "✅ Relatório HTML gerado em: $HTML_REPORT"

# Converte HTML para PDF usando wkhtmltopdf
if command -v wkhtmltopdf >/dev/null 2>&1; then
  wkhtmltopdf "$HTML_REPORT" "$PDF_REPORT"
  echo "✅ Relatório PDF gerado em: $PDF_REPORT"
else
  echo "⚠️  wkhtmltopdf não está instalado. Apenas o relatório HTML foi gerado."
  echo "   Para gerar PDF, instale com: sudo apt install wkhtmltopdf"
fi