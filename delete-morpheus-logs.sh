#!/bin/bash

echo "Limpando logs da interface Morpheus Health..."

# Verificar se é root
if [[ $EUID -ne 0 ]]; then
    echo "Este script deve ser executado como root"
    exit 1
fi

# Arquivo que alimenta Administration > Health > Morpheus Logs
MORPHEUS_UI_LOG="/var/log/morpheus/morpheus-ui/current"

if [[ -f "$MORPHEUS_UI_LOG" ]]; then
    # Mostrar tamanho atual
    current_size=$(du -sh "$MORPHEUS_UI_LOG" | cut -f1)
    echo "Tamanho atual do log da UI: $current_size"
    
    # Confirmar ação
    read -p "Deseja limpar o log da interface Morpheus? (s/N): " confirm
    if [[ "$confirm" =~ ^[sS]$ ]]; then
        # Truncar arquivo sem parar serviços
        truncate -s 0 "$MORPHEUS_UI_LOG"
        echo "✅ Log da interface Morpheus limpo com sucesso!"
        echo "ℹ️  Atualize a página Administration > Health > Morpheus Logs"
    else
        echo "Operação cancelada"
    fi
else
    echo "❌ Arquivo de log não encontrado: $MORPHEUS_UI_LOG"
fi
