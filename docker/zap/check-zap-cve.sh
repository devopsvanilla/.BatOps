#!/bin/bash
set -euo pipefail

# Verifica se o usuário passou uma URL
if [ -z "${1:-}" ]; then
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

# Função para executar o baseline com uma imagem específica
run_scan_with_image() {
  local image="$1"
  echo "📦 Usando imagem: $image"

  # Se DRY_RUN estiver setado, simula geração do relatório
  if [[ -n "${DRY_RUN:-}" ]]; then
    echo "🧪 DRY_RUN ativo - simulando scan e criando HTML fictício"
    cat >"$HTML_REPORT" <<'EOF'
<!DOCTYPE html><html><head><meta charset="utf-8"><title>ZAP Baseline Report (DRY RUN)</title></head><body><h1>ZAP Baseline Report (DRY RUN)</h1><p>Este é um relatório de teste.</p></body></html>
EOF
    return 0
  fi

  # Garante que o Docker está disponível
  if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker não encontrado. Instale e tente novamente."
    return 1
  fi

  if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker não está rodando ou o usuário não tem permissão (verifique 'docker ps')."
    return 1
  fi

  echo "🔍 Executando scan de segurança em: $URL"
  set +e
  docker run --rm \
    -v "$RESULTS_DIR:/zap/wrk:rw" \
    -t "$image" zap-baseline.py \
    -t "$URL" \
    -r "$(basename "$HTML_REPORT")"
  local rc=$?
  set -e
  return $rc
}

# Pergunta ao usuário qual imagem deseja usar
echo "Escolha a imagem Docker para executar o scan ZAP:"
echo "1) ghcr.io/zaproxy/zaproxy:stable (GHCR, mais recente)"
echo "2) owasp/zap2docker-stable (Docker Hub, estável)"
echo "3) owasp/zap2docker-weekly (Docker Hub, semanal)"
echo "4) DRY_RUN (simulação, sem Docker)"
read -p "Digite o número da opção desejada [1-4]: " ZAP_OPT

case "$ZAP_OPT" in
  1)
    ZAP_IMAGE="ghcr.io/zaproxy/zaproxy:stable"
    ;;
  2)
    ZAP_IMAGE="owasp/zap2docker-stable"
    ;;
  3)
    ZAP_IMAGE="owasp/zap2docker-weekly"
    ;;
  4)
    DRY_RUN=1
    ;;
  *)
    echo "Opção inválida. Abortando."
    exit 10
    ;;
esac

# Executa o scan com a imagem escolhida
if [[ -n "${DRY_RUN:-}" ]]; then
  run_scan_with_image "dummy"
else
  run_scan_with_image "$ZAP_IMAGE"
fi

# Verifica se o relatório HTML foi gerado
if [ ! -f "$HTML_REPORT" ]; then
  echo "❌ Erro: Relatório HTML não foi gerado"
  echo "Dicas de troubleshooting:"
  echo "  - Verifique conectividade com os registries (ghcr.io, registry-1.docker.io)"
  echo "  - Se estiver atrás de proxy, exporte HTTP_PROXY/HTTPS_PROXY para o Docker"
  echo "  - Em ambientes corporativos, o acesso ao GHCR pode ser bloqueado (use 'owasp/zap2docker-stable')"
  echo "  - Você pode escolher a imagem definindo ZAP_IMAGE=..."
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