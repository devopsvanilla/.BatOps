#!/usr/bin/env bash
set -euo pipefail

# fix-github-ado-conflict.sh
# Diagnostica (e opcionalmente corrige) conflitos entre o helper de
# credencial usado pelo GitHub CLI (gh) e o helper configurado para o
# Azure DevOps (Git Credential Manager), garantindo que ambos continuem
# funcionando lado a lado.
#
# O risco: um "credential.helper" GLOBAL genérico (sem escopo de URL) é
# testado pelo Git para QUALQUER host, incluindo github.com. Se esse helper
# genérico for adicionado (por exemplo, por uma instalação do GCM que
# rodou 'git-credential-manager configure' sem escopo), ele pode entrar em
# conflito com o helper escopado do 'gh' e quebrar a autenticação com o
# GitHub configurada anteriormente.
#
# Uso:
#   ./fix-github-ado-conflict.sh [--fix]
#
#   --fix   Remove helpers genéricos (não escopados) que conflitem e faz
#           backup do ~/.gitconfig antes de alterar. Sem essa flag, o
#           script apenas diagnostica (somente leitura).

FIX=false
for arg in "$@"; do
  case "$arg" in
    --fix) FIX=true ;;
    -h|--help)
      echo "Uso: $0 [--fix]"
      exit 0
      ;;
  esac
done

if ! command -v git >/dev/null 2>&1; then
  echo "❌ Git não encontrado." >&2
  exit 1
fi

echo "🔎 Analisando configuração global de credenciais do Git..."
echo ""

CONFIG_LIST="$(git config --global --list 2>/dev/null || true)"

# credential.helper genérico (sem escopo de URL), ex.: "credential.helper=manager"
GENERIC_HELPERS="$(echo "$CONFIG_LIST" | grep -E '^credential\.helper=' || true)"

# helpers escopados por host, ex.: "credential.https://github.com.helper=..."
SCOPED_GITHUB="$(echo "$CONFIG_LIST" | grep -E '^credential\.https://(gist\.)?github\.com\.helper=' || true)"
SCOPED_ADO="$(echo "$CONFIG_LIST" | grep -E '^credential\.https://(dev\.azure\.com|\*\.visualstudio\.com)\.helper=' || true)"

echo "Helpers escopados para GitHub:"
if [ -n "$SCOPED_GITHUB" ]; then
  echo "$SCOPED_GITHUB" | sed 's/^/  ✅ /'
else
  echo "  ⚠️ Nenhum encontrado (rode: gh auth setup-git)"
fi

echo ""
echo "Helpers escopados para Azure DevOps:"
if [ -n "$SCOPED_ADO" ]; then
  echo "$SCOPED_ADO" | sed 's/^/  ✅ /'
else
  echo "  ⚠️ Nenhum encontrado (rode: ./configure-ado-access.sh)"
fi

echo ""
CONFLICT=false
if [ -n "$GENERIC_HELPERS" ]; then
  CONFLICT=true
  echo "⚠️ Encontrado(s) credential.helper GLOBAL genérico(s) (sem escopo de URL):"
  echo "$GENERIC_HELPERS" | sed 's/^/  /'
  echo ""
  echo "   Isso pode ser testado pelo Git também para github.com e causar"
  echo "   prompts inesperados ou substituir o helper do 'gh'."
else
  echo "✅ Nenhum credential.helper genérico encontrado. Sem conflito de escopo detectado."
fi

echo ""

if [ "$CONFLICT" = true ]; then
  if [ "$FIX" = true ]; then
    BACKUP="$HOME/.gitconfig.bak-$(date +%Y%m%d%H%M%S)"
    cp "$HOME/.gitconfig" "$BACKUP"
    echo "🛟 Backup criado em: $BACKUP"

    echo "🛠️  Removendo credential.helper genérico(s)..."
    git config --global --unset-all credential.helper || true

    echo "🛠️  Reafirmando helper escopado do GitHub (via gh)..."
    if command -v gh >/dev/null 2>&1; then
      gh auth setup-git
    else
      echo "  ⚠️ 'gh' não encontrado no PATH; configure manualmente o helper do GitHub."
    fi

    echo "🛠️  Reafirmando helpers escopados do Azure DevOps..."
    git config --global --unset-all "credential.https://dev.azure.com.helper" 2>/dev/null || true
    git config --global --add "credential.https://dev.azure.com.helper" "manager"
    git config --global --unset-all "credential.https://*.visualstudio.com.helper" 2>/dev/null || true
    git config --global --add "credential.https://*.visualstudio.com.helper" "manager"

    echo ""
    echo "✅ Conflito corrigido. Configuração final relevante:"
    git config --global --list | grep -E '^credential\.' | sed 's/^/  /'
  else
    echo "ℹ️  Rode novamente com '--fix' para corrigir automaticamente (com backup do ~/.gitconfig)."
    exit 1
  fi
else
  exit 0
fi
