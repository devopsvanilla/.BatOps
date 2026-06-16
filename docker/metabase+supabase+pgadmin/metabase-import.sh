#!/usr/bin/env bash
set -euo pipefail

# Importa artefatos de Metabase serializados (ex: aplicações, coleções, dashboards)
# Uso:
#   METABASE_URL=http://localhost:3000 \
#   METABASE_API_KEY=... \
#   ./metabase-import.sh ./metabase/dashboards/exemplo.json

FILE_PATH="${1:-}"
if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  echo "[ERRO] Informe um arquivo válido para importação."
  echo "Exemplo: ./metabase-import.sh ./metabase/dashboards/base.json"
  exit 1
fi

: "${METABASE_URL:?Defina METABASE_URL}"
: "${METABASE_API_KEY:?Defina METABASE_API_KEY}"

curl -sS -X POST \
  "$METABASE_URL/api/ee/serialization/import" \
  -H "x-api-key: $METABASE_API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary "@$FILE_PATH"

echo

echo "[OK] Importação solicitada: $FILE_PATH"
