#!/bin/bash
# cd-git-root.sh: Vai para a raiz do repositório git corrente

# Detecta a raiz do repositório git
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -z "$GIT_ROOT" ]; then
  echo "Não está em um repositório git."
  exit 1
fi

cd "$GIT_ROOT" || exit

echo "Diretório alterado para a raiz do repositório: $GIT_ROOT"
