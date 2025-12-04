#!/bin/bash

# Nome do arquivo de saída
CAST_FILE="terminal_$(date +%Y%m%d_%H%M%S).cast"

# Verifica se o asciinema está instalado
if ! command -v asciinema &> /dev/null; then
    echo "📦 Instalando asciinema..."
    sudo apt update && sudo apt install -y asciinema
else
    echo "✅ Asciinema já está instalado."
fi

# Inicia a gravação no diretório atual
echo "🎬 Iniciando gravação do terminal..."
asciinema rec "$CAST_FILE"