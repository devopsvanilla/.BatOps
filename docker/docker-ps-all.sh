#!/usr/bin/bash

clear

# Script para listar containers de todos os contextos Docker configurados
# Uso: ./docker-ps-all.sh [--full]
# --full: exibe todos os dados dos containers
# (padrão): exibe apenas nome, estado e porta exposta

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Emojis
CONTAINER_EMOJI="📦"
RUNNING_EMOJI="✅"
STOPPED_EMOJI="⛔"
PORT_EMOJI="🔌"
CONTEXT_EMOJI="🔗"
ERROR_EMOJI="❌"

# Flag para modo full
FULL_MODE=false
[[ "$1" == "--full" ]] && FULL_MODE=true

# Função para exibir header
show_header() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE} ${CYAN}Docker Containers - Todos os Contextos${BLUE}${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
}

# Função para exibir contexto
show_context_header() {
    local context="$1"
    echo -e "${CONTEXT_EMOJI} ${CYAN}Contexto:${NC} ${YELLOW}${context}${NC}"
    echo -e "${GRAY}────────────────────────────────────────────────────────────────${NC}"
}

# Função para formatar estado
format_status() {
    local status="$1"
    if [[ "$status" == "running" ]]; then
        echo -n -e "${GREEN}${RUNNING_EMOJI} running${NC}"
    elif [[ "$status" == "exited" ]]; then
        echo -n -e "${RED}${STOPPED_EMOJI} exited${NC}"
    else
        echo -n -e "${YELLOW}⚠️  ${status}${NC}"
    fi
}

# Função principal
main() {
    show_header
    
    # Obter lista de contextos
    local contexts
    contexts=$(docker context ls --format "{{.Name}}" 2>/dev/null)
    
    if [[ -z "$contexts" ]]; then
        echo -e "${ERROR_EMOJI} ${RED}Nenhum contexto Docker encontrado${NC}"
        exit 1
    fi
    
    local context_count=0
    local total_containers=0
    
    while IFS= read -r context; do
        # Pular linhas vazias
        [[ -z "$context" ]] && continue
        
        # Verificar se o contexto está acessível
        if ! docker --context "$context" ps -a &>/dev/null 2>&1; then
            echo -e "${ERROR_EMOJI} ${RED}Contexto inacessível: ${context}${NC}\n"
            continue
        fi
        
        ((context_count++))
        show_context_header "$context"
        
        # Obter containers
        local containers
        containers=$(docker --context "$context" ps -a --format "{{json .}}" 2>/dev/null)
        
        if [[ -z "$containers" ]]; then
            echo -e "  ${GRAY}(nenhum container)${NC}\n"
            continue
        fi
        
        local container_count=0
        
        if [[ "$FULL_MODE" == true ]]; then
            # Modo completo
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                
                # Extrair dados usando jq ou grep/awk
                local id=$(echo "$line" | grep -o '"ID":"[^"]*' | cut -d'"' -f4 | cut -c1-12)
                local name=$(echo "$line" | grep -o '"Names":"[^"]*' | cut -d'"' -f4)
                local image=$(echo "$line" | grep -o '"Image":"[^"]*' | cut -d'"' -f4)
                local status=$(echo "$line" | grep -o '"Status":"[^"]*' | cut -d'"' -f4)
                local ports=$(echo "$line" | grep -o '"Ports":"[^"]*' | cut -d'"' -f4)
                local created=$(echo "$line" | grep -o '"CreatedAt":"[^"]*' | cut -d'"' -f4)
                local state=$(echo "$status" | awk '{print $1}')
                
                echo -e "  ${CONTAINER_EMOJI} ${CYAN}${name}${NC}"
                echo -e "     ${GRAY}ID:${NC} $id"
                echo -e "     ${GRAY}Imagem:${NC} $image"
                echo -e "     ${GRAY}Estado:${NC} $(format_status "$state")"
                [[ -n "$ports" && "$ports" != "<none>" ]] && echo -e "     ${PORT_EMOJI} ${GRAY}Portas:${NC} $ports"
                echo -e "     ${GRAY}Criado:${NC} $created"
                echo ""
                
                ((container_count++))
            done <<< "$containers"
        else
            # Modo simples
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                
                local name=$(echo "$line" | grep -o '"Names":"[^"]*' | cut -d'"' -f4)
                local status=$(echo "$line" | grep -o '"Status":"[^"]*' | cut -d'"' -f4)
                local ports=$(echo "$line" | grep -o '"Ports":"[^"]*' | cut -d'"' -f4)
                local state=$(echo "$status" | awk '{print $1}')
                
                local port_info=""
                if [[ -n "$ports" && "$ports" != "<none>" ]]; then
                    port_info="${PORT_EMOJI} $ports"
                fi
                
                echo -e "  ${CONTAINER_EMOJI} ${CYAN}${name}${NC} | $(format_status "$state") | $port_info"
                ((container_count++))
            done <<< "$containers"
        fi
        
        ((total_containers += container_count))
        echo ""
    done <<< "$contexts"
    
    # Summary
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${NC} Resumo: ${context_count} contexto(s) | ${total_containers} container(s) total"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
}

# Executar
main