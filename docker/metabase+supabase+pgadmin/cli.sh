#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPABASE_DIR="${SUPABASE_DIR:-$SCRIPT_DIR/supabase}"

if command -v supabase >/dev/null 2>&1; then
  (cd "$SUPABASE_DIR" && supabase "$@")
  exit 0
fi

echo "[WARN] supabase CLI não encontrado localmente. Usando container supabase/cli..."
docker run --rm -it \
  -v "$SUPABASE_DIR:/work" \
  -w /work \
  --network host \
  supabase/cli:latest "$@"
