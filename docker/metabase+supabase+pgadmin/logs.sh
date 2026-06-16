#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPABASE_DIR="${SUPABASE_DIR:-$SCRIPT_DIR/supabase}"
SUPABASE_ENV_FILE="${SUPABASE_ENV_FILE:-$SUPABASE_DIR/.env}"

docker compose \
  --env-file "$SUPABASE_ENV_FILE" \
  -f "$SUPABASE_DIR/docker-compose.yml" \
  -f "$SCRIPT_DIR/docker-compose.yml" \
  logs -f "$@"
