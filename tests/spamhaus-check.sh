#!/bin/bash

# Verifica dependência do comando mail
if ! command -v mail &> /dev/null
then
    echo "O comando 'mail' não foi encontrado."
    read -p "Deseja instalar o pacote mailutils agora? (s/n): " choice
    case "$choice" in
        s|S )
            echo "Instalando mailutils..."
            sudo apt update && sudo apt install -y mailutils
            if ! command -v mail &> /dev/null; then
                echo "Falha ao instalar mailutils. Cancelando execução."
                exit 1
            fi
            ;;
        * )
            echo "Instalação cancelada. Saindo do script."
            exit 1
            ;;
    esac
fi

# Parâmetros obrigatórios
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Uso: $0 <domínio> <IP>"
    echo "Exemplo: $0 devopsvanilla.com.br 138.94.84.20"
    exit 1
fi

DOMAIN="$1"
IP="$2"
EMAIL="postmaster@$DOMAIN"
OUTPUT="/tmp/spamhaus_check_${IP//./_}_$(date +%F).log"

check_spamhaus() {
    echo "Relatório de listagem Spamhaus" > "$OUTPUT"
    echo "IP verificado: $IP" >> "$OUTPUT"
    echo "Domínio: $DOMAIN" >> "$OUTPUT"
    echo "Data: $(date)" >> "$OUTPUT"
    echo "--------------------------------------" >> "$OUTPUT"

    SPAMHAUS_RESULT=$(curl -s "https://www.spamhaus.org/query/ip/$IP")
    if echo "$SPAMHAUS_RESULT" | grep -q "is not listed"; then
        echo "✅ IP NÃO está listado em Spamhaus." >> "$OUTPUT"
    else
        echo "❌ IP ESTÁ listado na Spamhaus!" >> "$OUTPUT"
        echo "Verifique detalhes: https://www.spamhaus.org/query/ip/$IP" >> "$OUTPUT"
    fi

    for LIST in zen sbl xbl pbl css; do
        DNSBL="$IP.$LIST.zen.spamhaus.org"
        RESULT_NSLOOKUP=$(nslookup "$DNSBL" 1.1.1.1 2>/dev/null)
        if echo "$RESULT_NSLOOKUP" | grep -qiE "name =|Address:"; then
            echo "⚠️ Listado em $LIST (DNSBL)" >> "$OUTPUT"
        else
            echo "✅ Não listado em $LIST (DNSBL)" >> "$OUTPUT"
        fi
    done
    echo "--------------------------------------" >> "$OUTPUT"
}

check_spamhaus
mail -s "Relatório diário Spamhaus para $DOMAIN ($IP)" "$EMAIL" < "$OUTPUT"
rm "$OUTPUT"
