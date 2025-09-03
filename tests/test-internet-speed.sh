#!/bin/bash

# Diretório temporário padrão para salvar os resultados
default_data_dir="/tmp/test-internet-speed"

# Função para verificar dependências
check_dependencies() {
    if ! command -v speedtest-cli &> /dev/null; then
        echo "A dependência 'speedtest-cli' não está instalada."
        read -p "Deseja instalá-la agora? (s/n): " install_choice
        if [[ "$install_choice" == "s" || "$install_choice" == "S" ]]; then
            sudo apt update && sudo apt install -y speedtest-cli
        else
            echo "Instale 'speedtest-cli' para executar este script. Saindo..."
            exit 1
        fi
    fi
}

# Função para exibir ajuda
show_help() {
    echo "Uso: $0 [opções]"
    echo ""
    echo "Opções:"
    echo "  --save <diretório>    Salva os resultados no diretório especificado (ou padrão: /tmp/test-internet-speed)"
    echo "  --help                Exibe esta mensagem de ajuda"
}

# Verifica dependências
check_dependencies

# Variáveis
save_results=false
data_dir="$default_data_dir"

# Verifica argumentos
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --save)
            save_results=true
            if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                data_dir="$2"
                shift
            fi
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Opção desconhecida: $1"
            show_help
            exit 1
            ;;
    esac
    shift
done

# Cria o diretório de saída se necessário
if $save_results; then
    if [[ "$data_dir" == "$default_data_dir" ]]; then
        mkdir -p "$data_dir"
    else
        if [[ ! -d "$data_dir" ]]; then
            mkdir -p "$data_dir"
        fi
    fi
fi

# Executa o teste de velocidade
result=$(speedtest-cli --json)

# Salva o resultado se a opção --save for informada
if $save_results; then
    output_file="$data_dir/$(date +%Y-%m-%d).log"
    echo "$result" >> "$output_file"
fi

# Exibe o resultado no terminal
echo "$result"
