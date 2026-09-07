#!/usr/bin/env bash

set -euo pipefail

# Wrapper não-interativo para execução periódica via cron.
# Carrega variáveis de um arquivo .env (mesmo diretório) e chama o audit-github.sh
# em modo --non-interactive, adequado para agendamento.
#
# Uso:
#   ./run-scheduled-audit.sh
#
# Configuração do cron (crontab -e), exemplo para rodar toda segunda-feira às 08:00:
#   0 8 * * 1 /caminho/completo/para/security/legitify/run-scheduled-audit.sh >> /caminho/completo/para/security/legitify/cron.log 2>&1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
else
  echo "[legitify-cron] ERRO: arquivo .env não encontrado em ${ENV_FILE}." >&2
  echo "[legitify-cron] Copie .env.example para .env e preencha os valores antes de agendar." >&2
  exit 1
fi

exec "${SCRIPT_DIR}/audit-github.sh" --non-interactive
