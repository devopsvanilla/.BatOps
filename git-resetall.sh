#!/usr/bin/env bash
# TODO: Revisar e adicionar set -euo pipefail — Issue #1

echo "Verificando alterações no repositório..."

# Lista arquivos modificados (not staged)
MODIFICADOS=$(git diff --name-only)

# Lista arquivos staged
STAGED=$(git diff --cached --name-only)

# Lista arquivos não rastreados (untracked)
NAO_RASTREADOS=$(git ls-files --others --exclude-standard)

# Exibe os arquivos encontrados
echo ""
echo "Arquivos modificados (não staged):"
echo "$MODIFICADOS"
echo ""
echo "Arquivos staged:"
echo "$STAGED"
echo ""
echo "Arquivos não rastreados:"
echo "$NAO_RASTREADOS"
echo ""

# Solicita confirmação
read -p "Deseja DESCARTAR todas essas alterações e remover arquivos não rastreados? (s/n): " CONFIRMA

if [[ "$CONFIRMA" == "s" || "$CONFIRMA" == "S" ]]; then
    echo "🔄 Revertendo alterações com git reset --hard..."
    git reset --hard

    echo "🧹 Removendo arquivos não rastreados com git clean -fd..."
    git clean -fd

    echo "✅ Repositório limpo. Tudo foi revertido ao último commit."
else
    echo "❌ Operação cancelada pelo usuário."
fi