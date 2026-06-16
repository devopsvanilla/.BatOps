#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPABASE_DIR="${SUPABASE_DIR:-$SCRIPT_DIR/supabase}"
SUPABASE_ENV_FILE="${SUPABASE_ENV_FILE:-$SUPABASE_DIR/.env}"
PGADMIN_DIR="$SCRIPT_DIR/pgadmin"

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
err() { echo "[ERRO] $*"; }

if [[ ! -f "$SUPABASE_DIR/docker-compose.yml" ]]; then
  err "Não encontrei $SUPABASE_DIR/docker-compose.yml"
  err "Execute primeiro: ./sync-supabase.sh"
  exit 1
fi

if [[ ! -f "$SUPABASE_ENV_FILE" ]]; then
  err "Não encontrei $SUPABASE_ENV_FILE"
  err "Copie $SUPABASE_DIR/.env.example para $SUPABASE_DIR/.env e configure os secrets."
  exit 1
fi

# Lê variáveis de um .env no estilo dotenv sem executar o arquivo como shell.
# Isso evita erros com valores contendo espaços (ex.: Default Organization).
read_dotenv_var() {
  local key="$1"
  local line raw value

  line=$(grep -m1 -E "^[[:space:]]*${key}=" "$SUPABASE_ENV_FILE" || true)
  [[ -n "$line" ]] || return 1

  raw="${line#*=}"
  # Remove CRLF quando o arquivo foi editado em Windows
  raw="${raw%$'\r'}"

  # Trim espaços à esquerda/direita
  value="${raw#"${raw%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"

  # Remove aspas externas simples/duplas, se existirem
  if [[ ${#value} -ge 2 ]]; then
    if [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "${value:0:1}" == "'" && "${value: -1}" == "'" ]]; then
      value="${value:1:${#value}-2}"
    fi
  fi

  printf '%s' "$value"
}

POSTGRES_PASSWORD="$(read_dotenv_var POSTGRES_PASSWORD || true)"
POOLER_TENANT_ID="$(read_dotenv_var POOLER_TENANT_ID || true)"
DASHBOARD_USERNAME="$(read_dotenv_var DASHBOARD_USERNAME || true)"
DASHBOARD_PASSWORD="$(read_dotenv_var DASHBOARD_PASSWORD || true)"
KONG_HTTP_PORT="$(read_dotenv_var KONG_HTTP_PORT || true)"
export POSTGRES_PASSWORD POOLER_TENANT_ID DASHBOARD_USERNAME DASHBOARD_PASSWORD KONG_HTTP_PORT

required_vars=(POSTGRES_PASSWORD POOLER_TENANT_ID DASHBOARD_USERNAME DASHBOARD_PASSWORD)
for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    err "Variável obrigatória ausente em $SUPABASE_ENV_FILE: $var_name"
    exit 1
  fi
done

# Defaults do overlay Metabase/pgAdmin
export HOST_BIND_IP="${HOST_BIND_IP:-127.0.0.1}"
export METABASE_PORT="${METABASE_PORT:-3000}"
export PGADMIN_PORT="${PGADMIN_PORT:-5050}"
export METABASE_DB_NAME="${METABASE_DB_NAME:-metabaseappdb}"
export METABASE_DB_PASSWORD="${METABASE_DB_PASSWORD:-$POSTGRES_PASSWORD}"
export METABASE_DB_USER_WITH_TENANT="${METABASE_DB_USER_WITH_TENANT:-postgres.${POOLER_TENANT_ID}}"
export PGADMIN_DB_HOST="${PGADMIN_DB_HOST:-supavisor}"
export PGADMIN_DB_PORT="${PGADMIN_DB_PORT:-5432}"
export PGADMIN_DB_NAME="${PGADMIN_DB_NAME:-postgres}"
export PGADMIN_DB_USER="${PGADMIN_DB_USER:-postgres.${POOLER_TENANT_ID}}"
export PGADMIN_DB_PASSWORD="${PGADMIN_DB_PASSWORD:-$POSTGRES_PASSWORD}"
export PGADMIN_DEFAULT_EMAIL="${PGADMIN_DEFAULT_EMAIL:-admin@admin.com}"
export PGADMIN_DEFAULT_PASSWORD="${PGADMIN_DEFAULT_PASSWORD:-$DASHBOARD_PASSWORD}"

mkdir -p "$SCRIPT_DIR/metabase/plugins" "$SCRIPT_DIR/metabase/data" "$PGADMIN_DIR/data" "$SCRIPT_DIR/volumes/db/init-scripts"

if [[ ! -f "$PGADMIN_DIR/servers.template.json" ]]; then
  err "Template do pgAdmin ausente: $PGADMIN_DIR/servers.template.json"
  exit 1
fi

sed \
  -e "s|__PGADMIN_DB_HOST__|$PGADMIN_DB_HOST|g" \
  -e "s|__PGADMIN_DB_PORT__|$PGADMIN_DB_PORT|g" \
  -e "s|__PGADMIN_DB_NAME__|$PGADMIN_DB_NAME|g" \
  -e "s|__PGADMIN_DB_USER__|$PGADMIN_DB_USER|g" \
  "$PGADMIN_DIR/servers.template.json" > "$PGADMIN_DIR/servers.json"

chmod 600 "$PGADMIN_DIR/servers.json"

printf '%s\n' "$PGADMIN_DB_HOST:$PGADMIN_DB_PORT:*:$PGADMIN_DB_USER:$PGADMIN_DB_PASSWORD" > "$PGADMIN_DIR/pgpassfile"
chmod 600 "$PGADMIN_DIR/pgpassfile"

if command -v sudo >/dev/null 2>&1; then
  sudo chown -R 5050:5050 "$PGADMIN_DIR/data" || warn "Não foi possível ajustar ownership do pgAdmin com sudo."
else
  warn "sudo não encontrado; seguindo sem ajustar ownership de pgadmin/data."
fi

info "Subindo Supabase + Metabase + pgAdmin"
docker compose \
  --env-file "$SUPABASE_ENV_FILE" \
  -f "$SUPABASE_DIR/docker-compose.yml" \
  -f "$SCRIPT_DIR/docker-compose.yml" \
  up -d "$@"

info "Stack iniciada."
info "Supabase Studio: http://${HOST_BIND_IP}:${KONG_HTTP_PORT:-8000}"
info "Metabase:        http://${HOST_BIND_IP}:${METABASE_PORT}"
info "pgAdmin:         http://${HOST_BIND_IP}:${PGADMIN_PORT}"
