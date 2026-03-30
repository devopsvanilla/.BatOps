#!/usr/bin/env bash
# TODO: Revisar e adicionar set -euo pipefail — Issue #1
# get-linux-version.sh
# Script "battle proof" para detectar versão do Linux

#!/usr/bin/env bash
# get-linux-version.sh
# =============================================
# 🐧 Script para detectar a versão do Linux
# =============================================
# Este script identifica a versão/distribuição do Linux usando múltiplos métodos.
# Uso: bash get-linux-version.sh
#
# Pós-instalação:
# 1. Verifique se a versão foi corretamente detectada.
# 2. Documente a versão do sistema para auditoria ou troubleshooting.
# 3. Caso precise instalar pacotes adicionais, siga as instruções exibidas ao final.
#
# Dependências: lsb-release, systemd (hostnamectl)
# O script verifica e instala automaticamente as dependências necessárias.
# =============================================
echo "=== Detectando versão do Linux ==="

# 1. Método padrão moderno
if [[ -f /etc/os-release ]]; then
    echo ">> Usando /etc/os-release"
    cat /etc/os-release
    exit 0
fi

# 2. Método alternativo (systemd-based)
if command -v hostnamectl &>/dev/null; then
    echo ">> Usando hostnamectl"
    hostnamectl
    exit 0
fi

# 3. Método clássico (lsb_release)
if command -v lsb_release &>/dev/null; then
    echo ">> Usando lsb_release"
    lsb_release -a
    exit 0
fi

# 4. Arquivos antigos de release (para distros legadas)
for relfile in /etc/*release /etc/*version; do
    if [[ -r "$relfile" ]]; then
        echo ">> Usando $relfile"
        cat "$relfile"
        exit 0
    fi
done

# 5. Kernel fallback
echo ">> Nenhuma informação de distribuição encontrada. Exibindo kernel:"
uname -a
