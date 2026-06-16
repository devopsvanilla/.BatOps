#!/usr/bin/env bash
set -euo pipefail

# Sincroniza os arquivos oficiais de self-hosting do Supabase para ./supabase
# Fonte oficial: https://github.com/supabase/supabase/tree/master/docker

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${SUPABASE_DIR:-$SCRIPT_DIR/supabase}"
REF="${SUPABASE_REF:-master}"
TMP_DIR="$(mktemp -d)"
REPO_URL="https://github.com/supabase/supabase.git"

log() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*" >&2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] Comando obrigatório não encontrado: $1" >&2
    exit 1
  }
}

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

require_cmd git
require_cmd rsync

clone_supabase() {
  local ref="$1"
  git clone --depth 1 --branch "$ref" "$REPO_URL" "$TMP_DIR/supabase"
}

log "Baixando Supabase docker (ref=$REF)..."
if ! clone_supabase "$REF"; then
  if [[ "$REF" != "main" ]]; then
    warn "Falha ao baixar ref '$REF'. Tentando fallback para 'main'..."
    rm -rf "$TMP_DIR/supabase"
    clone_supabase "main"
    REF="main"
  else
    echo "[ERROR] Não foi possível clonar o repositório Supabase (ref=$REF)." >&2
    exit 1
  fi
fi

mkdir -p "$TARGET_DIR"
rsync -a --delete "$TMP_DIR/supabase/docker/" "$TARGET_DIR/"

if [[ ! -f "$TARGET_DIR/.env" ]]; then
  if [[ -f "$TARGET_DIR/.env.example" ]]; then
    cp "$TARGET_DIR/.env.example" "$TARGET_DIR/.env"
    log "Criado $TARGET_DIR/.env a partir de .env.example"
  else
    warn "Arquivo .env.example não encontrado em $TARGET_DIR; .env não foi criado automaticamente."
  fi
fi

echo "[OK] Supabase sincronizado em: $TARGET_DIR (ref=$REF)"
log "Próximo passo: editar $TARGET_DIR/.env com secrets fortes."
