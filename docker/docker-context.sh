#!/usr/bin/env bash
# TODO: Revisar e adicionar set -euo pipefail — Issue #1

# Script para gerenciar contextos Docker
# Permite listar e selecionar o contexto Docker padrão com UI amigável

# Cores ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Emojis
DOCKER_EMOJI="🐳"
CHECKMARK="✅"
ARROW="➜"
STAR="⭐"
WARNING="⚠️"
INFO="ℹ️"
SUCCESS="🎉"

# Função para exibir cabeçalho
show_header() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${NC}           ${DOCKER_EMOJI}  ${MAGENTA}GERENCIADOR DE CONTEXTOS DOCKER${NC}  ${DOCKER_EMOJI}${CYAN}${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Função para exibir informações
show_info() {
    echo -e "${BLUE}${INFO} $1${NC}"
}

# Função para exibir sucesso
show_success() {
    echo -e "${GREEN}${SUCCESS} $1${NC}"
}

# Função para exibir warning
show_warning() {
    echo -e "${YELLOW}${WARNING} $1${NC}"
}

# Função para exibir erro
show_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Verifica se Docker está instalado
check_docker() {
    if ! command -v docker &> /dev/null; then
        show_error "Docker não está instalado ou não está no PATH"
        exit 1
    fi
}

# Lista os contextos Docker disponíveis
list_contexts() {
    show_header
    show_info "Buscando contextos Docker disponíveis..."
    echo ""
    
    # Obtém o contexto atual
    current_context=$(docker context ls --format='table {{.Name}}\t{{.Current}}' | awk '$2=="true" {print $1}')
    
    # Obtém lista de contextos
    contexts=($(docker context ls --format='{{.Name}}'))
    
    if [ ${#contexts[@]} -eq 0 ]; then
        show_warning "Nenhum contexto Docker encontrado"
        return 1
    fi
    
    echo -e "${CYAN}Contextos disponíveis:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local index=1
    for context in "${contexts[@]}"; do
        if [ "$context" = "$current_context" ]; then
            echo -e "${GREEN}${CHECKMARK}${NC} [$index] ${STAR} ${YELLOW}${context}${NC} (${GREEN}ativo${NC})"
        else
            echo -e "   [$index] ${CYAN}${context}${NC}"
        fi
        index=$((index + 1))
    done
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}Contexto atual: ${YELLOW}${current_context}${NC}"
    echo ""
}

# Função para selecionar um contexto
select_context() {
    local contexts=($(docker context ls --format='{{.Name}}'))
    local current_context=$(docker context ls --format='table {{.Name}}\t{{.Current}}' | awk '$2=="true" {print $1}')
    
    if [ ${#contexts[@]} -eq 0 ]; then
        return 1
    fi
    
    while true; do
        echo -e "${MAGENTA}${ARROW} Digite o número do contexto desejado (ou 'q' para sair):${NC} "
        read -r choice
        
        # Verifica se o usuário quer sair
        if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
            show_info "Operação cancelada"
            return 0
        fi
        
        # Valida se é um número
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            show_error "Entrada inválida. Digite um número ou 'q' para sair"
            continue
        fi
        
        # Valida se o número está no intervalo correto
        if [ "$choice" -lt 1 ] || [ "$choice" -gt ${#contexts[@]} ]; then
            show_error "Número fora do intervalo. Digite um número entre 1 e ${#contexts[@]}"
            continue
        fi
        
        # Obtém o contexto selecionado (converte para índice de array 0-based)
        selected_context="${contexts[$((choice - 1))]}"
        
        # Verifica se é o mesmo contexto atual
        if [ "$selected_context" = "$current_context" ]; then
            show_warning "Este contexto já está ativo!"
            echo ""
            continue
        fi
        
        # Alterna para o novo contexto
        if docker context use "$selected_context" &> /dev/null; then
            show_success "Contexto alterado para: ${YELLOW}${selected_context}${NC}"
            echo ""
            
            # Exibe informações do novo contexto
            show_info "Exibindo informações do contexto..."
            docker context inspect "$selected_context" | head -20
            echo ""
            return 0
        else
            show_error "Erro ao alternar para o contexto: ${selected_context}"
            return 1
        fi
    done
}

# Menu principal
main() {
    check_docker
    
    while true; do
        list_contexts
        
        echo -e "${MAGENTA}Opções:${NC}"
        echo -e "  [1] ${BLUE}Selecionar novo contexto${NC}"
        echo -e "  [2] ${BLUE}Exibir informações do contexto atual${NC}"
        echo -e "  [3] ${BLUE}Sair${NC}"
        echo ""
        echo -e "${MAGENTA}${ARROW} Escolha uma opção:${NC} "
        read -r option
        
        case "$option" in
            1)
                echo ""
                select_context
                echo ""
                read -p "Pressione ENTER para continuar..."
                clear
                ;;
            2)
                echo ""
                current_context=$(docker context ls --format='table {{.Name}}\t{{.Current}}' | awk '$2=="true" {print $1}')
                show_info "Informações do contexto: ${YELLOW}${current_context}${NC}"
                echo ""
                docker context inspect "$current_context"
                echo ""
                read -p "Pressione ENTER para continuar..."
                clear
                ;;
            3)
                echo ""
                show_success "Até logo! ${DOCKER_EMOJI}"
                exit 0
                ;;
            *)
                show_error "Opção inválida"
                sleep 1
                clear
                ;;
        esac
    done
}

# Executa o script
main