#!/usr/bin/env bash
set -euo pipefail

# set-git-profile.sh
# Garante que o perfil global do Git (user.name e user.email) esteja
# configurado, exigido para autoria correta de commits no Azure DevOps,
# GitHub ou qualquer outro provedor Git.
#
# Uso:
#   ./set-git-profile.sh [--name "Nome Completo"] [--email "email@dominio"] [--force]
#
#   --force  Sobrescreve valores já configurados, mesmo que já existam.

NAME=""
EMAIL=""
FORCE=false

while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="${2:-}"; shift 2 ;;
    --email) EMAIL="${2:-}"; shift 2 ;;
    --force) FORCE=true; shift ;;
    -h|--help)
      echo "Uso: $0 [--name \"Nome Completo\"] [--email \"email@dominio\"] [--force]"
      exit 0
      ;;
    *)
      echo "⚠️ Argumento desconhecido: $1" >&2
      shift
      ;;
  esac
done

if ! command -v git >/dev/null 2>&1; then
  echo "❌ Git não encontrado. Instale o git antes de continuar." >&2
  exit 1
fi

CURRENT_NAME="$(git config --global user.name 2>/dev/null || true)"
CURRENT_EMAIL="$(git config --global user.email 2>/dev/null || true)"

if [ -n "$CURRENT_NAME" ] && [ -n "$CURRENT_EMAIL" ] && [ "$FORCE" = false ]; then
  echo "✅ Perfil Git já configurado:"
  echo "   user.name  = $CURRENT_NAME"
  echo "   user.email = $CURRENT_EMAIL"
  echo "   (use --force para alterar)"
  exit 0
fi

if [ -z "$NAME" ]; then
  if [ -t 0 ]; then
    read -r -p "Nome completo para commits [${CURRENT_NAME:-}]: " NAME
    NAME="${NAME:-$CURRENT_NAME}"
  else
    NAME="$CURRENT_NAME"
  fi
fi

if [ -z "$EMAIL" ]; then
  if [ -t 0 ]; then
    read -r -p "E-mail para commits [${CURRENT_EMAIL:-}]: " EMAIL
    EMAIL="${EMAIL:-$CURRENT_EMAIL}"
  else
    EMAIL="$CURRENT_EMAIL"
  fi
fi

if [ -z "$NAME" ] || [ -z "$EMAIL" ]; then
  echo "❌ Nome e e-mail são obrigatórios. Use --name e --email ou execute em um terminal interativo." >&2
  exit 1
fi

git config --global user.name "$NAME"
git config --global user.email "$EMAIL"

echo "✅ Perfil Git configurado:"
echo "   user.name  = $(git config --global user.name)"
echo "   user.email = $(git config --global user.email)"
