#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPABASE_DIR="${SUPABASE_DIR:-$SCRIPT_DIR/supabase}"
SUPABASE_ENV_FILE="${SUPABASE_ENV_FILE:-$SUPABASE_DIR/.env}"

if [[ ! -f "$SUPABASE_DIR/docker-compose.yml" ]]; then
  echo "[ERRO] Não encontrei $SUPABASE_DIR/docker-compose.yml"
  exit 1
fi

if [[ ! -f "$SUPABASE_ENV_FILE" ]]; then
  echo "[ERRO] Não encontrei $SUPABASE_ENV_FILE"
  exit 1
fi

docker compose \
  --env-file "$SUPABASE_ENV_FILE" \
  -f "$SUPABASE_DIR/docker-compose.yml" \
  -f "$SCRIPT_DIR/docker-compose.yml" \
  down "$@"
