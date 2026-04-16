#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_DIR="$SCRIPT_DIR/secrets"
PGADMIN_DIR="$SCRIPT_DIR/pgadmin"

# Verifica se os arquivos de secrets existem
if [[ ! -f "$SECRETS_DIR/postgres_password.txt" || ! -f "$SECRETS_DIR/pgadmin_password.txt" ]]; then
  echo "ERRO: Arquivos de secrets não encontrados em $SECRETS_DIR"
  echo "Execute primeiro:"
  echo "  openssl rand -base64 32 | tr -d '\\n' > secrets/postgres_password.txt"
  echo "  openssl rand -base64 32 | tr -d '\\n' > secrets/pgadmin_password.txt"
  exit 1
fi

# Garante que o diretório de dados do pgAdmin pertence ao uid 5050 (usuário pgadmin no container)
mkdir -p "$SCRIPT_DIR/pgadmin/data"
sudo chown -R 5050:5050 "$SCRIPT_DIR/pgadmin/data"
echo "✓ Ownership de pgadmin/data ajustado para uid 5050"

# Gera o pgpassfile a partir do secret do postgres (host:port:db:user:senha)
PG_PASS=$(cat "$SECRETS_DIR/postgres_password.txt")
echo "postgres:5432:*:metabase:$PG_PASS" > "$PGADMIN_DIR/pgpassfile"
chmod 600 "$PGADMIN_DIR/pgpassfile"
echo "✓ pgpassfile gerado em pgadmin/pgpassfile"

# Garante que os secrets são legíveis pelo usuário do container (pgadmin uid 5050)
chmod 644 "$SECRETS_DIR/postgres_password.txt"
chmod 644 "$SECRETS_DIR/pgadmin_password.txt"
echo "✓ Permissões dos secrets ajustadas"

# Sobe a stack
docker compose up -d "$@"
