#!/bin/bash

################################################################################
# Script para limpeza de logs do Morpheus Data Enterprise
################################################################################
#
# DESCRIÇÃO:
#   Este script limpa os logs do sistema Morpheus Data Enterprise de forma
#   segura, mantendo os arquivos de log ativos (current) vazios e removendo
#   logs arquivados antigos.
#
# AUTOR: Script automatizado
# VERSÃO: 1.0
# DATA: 2025-09-12
#
################################################################################
# FUNCIONALIDADES:
################################################################################
#
# --all
#   Limpa todos os tipos de logs do Morpheus (sistema + elasticsearch)
#
# --system-only
#   Limpa apenas os logs de sistema do Morpheus (/var/log/morpheus/)
#
# --elasticsearch-only
#   Limpa apenas os logs/índices do Elasticsearch (dados de instâncias)
#
# --dry-run
#   Mostra o que seria limpo sem executar as ações
#
# --force
#   Executa a limpeza sem confirmação interativa
#
# --help, -h
#   Exibe esta ajuda
#
################################################################################
# EXEMPLOS DE USO:
################################################################################
#
# Limpar todos os logs:
#   sudo ./morpheus-log-cleanup.sh --all
#
# Apenas logs de sistema:
#   sudo ./morpheus-log-cleanup.sh --system-only
#
# Visualizar o que seria limpo:
#   sudo ./morpheus-log-cleanup.sh --all --dry-run
#
# Limpeza forçada sem confirmação:
#   sudo ./morpheus-log-cleanup.sh --all --force
#
################################################################################
# LOGS LIMPOS:
################################################################################
#
# Logs de Sistema:
# - /var/log/morpheus/morpheus-ui/current (truncado)
# - /var/log/morpheus/morpheus-ui/*.log.* (removidos)
# - /var/log/morpheus/elasticsearch/current (truncado)
# - /var/log/morpheus/mysql/current (truncado)
# - /var/log/morpheus/nginx/current (truncado)
# - /var/log/morpheus/rabbitmq/current (truncado)
# - /var/log/morpheus/check-server/current (truncado)
# - /var/log/morpheus/guacd/current (truncado)
#
# Logs de Instâncias (Elasticsearch):
# - Índices morpheus-* (removidos)
# - Todos os logs de instâncias armazenados
#
################################################################################
# AVISOS IMPORTANTES:
################################################################################
#
# - Este script requer permissões de root
# - Logs de instâncias são perdidos permanentemente ao limpar Elasticsearch
# - Os serviços Morpheus são temporariamente parados durante a limpeza
# - Um backup dos logs pode ser criado antes da limpeza se solicitado
#
################################################################################

# Configurações
MORPHEUS_LOG_DIR="/var/log/morpheus"
SCRIPT_NAME="$(basename "$0")"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variáveis de controle
DRY_RUN=false
FORCE_MODE=false
CLEAN_SYSTEM=false
CLEAN_ELASTICSEARCH=false

# Função para exibir ajuda
show_help() {
    cat << EOF
Uso: $SCRIPT_NAME [OPÇÕES]

Opções:
  --all                 Limpa todos os logs (sistema + elasticsearch)
  --system-only         Limpa apenas logs de sistema
  --elasticsearch-only  Limpa apenas logs/índices do Elasticsearch
  --dry-run            Mostra o que seria limpo sem executar
  --force              Executa sem confirmação interativa
  --help               Exibe esta ajuda

Exemplos:
  $SCRIPT_NAME --all
  $SCRIPT_NAME --system-only --dry-run
  $SCRIPT_NAME --elasticsearch-only --force

EOF
}

# Função para verificar permissões
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Erro: Este script deve ser executado como root${NC}"
        echo -e "${YELLOW}Use: sudo $0 $*${NC}"
        exit 1
    fi
}

# Função para verificar se Morpheus está instalado
check_morpheus_installation() {
    if [[ ! -d "$MORPHEUS_LOG_DIR" ]]; then
        echo -e "${RED}Erro: Diretório de logs do Morpheus não encontrado: $MORPHEUS_LOG_DIR${NC}"
        echo -e "${YELLOW}Verifique se o Morpheus Data Enterprise está instalado${NC}"
        exit 1
    fi

    if ! command -v morpheus-ctl &> /dev/null; then
        echo -e "${RED}Erro: Comando 'morpheus-ctl' não encontrado${NC}"
        echo -e "${YELLOW}Verifique se o Morpheus Data Enterprise está instalado corretamente${NC}"
        exit 1
    fi
}

# Função para calcular tamanho dos logs
calculate_log_size() {
    local path="$1"
    if [[ -d "$path" ]]; then
        du -sh "$path" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}

# Função para listar arquivos que seriam limpos
list_files_to_clean() {
    echo -e "${BLUE}=== ANÁLISE DE LOGS ===${NC}"
    
    if [[ "$CLEAN_SYSTEM" == true ]]; then
        echo -e "\n${CYAN}Logs de Sistema do Morpheus:${NC}"
        local total_size=0
        
        for service in morpheus-ui elasticsearch mysql nginx rabbitmq check-server guacd; do
            local service_dir="$MORPHEUS_LOG_DIR/$service"
            if [[ -d "$service_dir" ]]; then
                local size=$(calculate_log_size "$service_dir")
                echo "  📁 $service/ - Tamanho: $size"
                
                # Listar arquivo current
                if [[ -f "$service_dir/current" ]]; then
                    local current_size=$(du -sh "$service_dir/current" 2>/dev/null | cut -f1)
                    echo "    📄 current - $current_size (será truncado)"
                fi
                
                # Listar arquivos arquivados
                local archived_count=$(find "$service_dir" -name "*.log.*" -o -name "@*" 2>/dev/null | wc -l)
                if [[ $archived_count -gt 0 ]]; then
                    echo "    🗂️  $archived_count arquivo(s) arquivado(s) (serão removidos)"
                fi
            fi
        done
    fi
    
    if [[ "$CLEAN_ELASTICSEARCH" == true ]]; then
        echo -e "\n${CYAN}Índices do Elasticsearch (logs de instâncias):${NC}"
        
        # Verificar se elasticsearch está rodando
        if curl -s "localhost:9200/_cluster/health" &>/dev/null; then
            local indices=$(curl -s "localhost:9200/_cat/indices/morpheus-*?h=index,store.size" 2>/dev/null)
            if [[ -n "$indices" ]]; then
                echo "$indices" | while read -r line; do
                    if [[ -n "$line" ]]; then
                        echo "  📊 $line (será removido)"
                    fi
                done
            else
                echo "  ✅ Nenhum índice morpheus-* encontrado"
            fi
        else
            echo "  ⚠️  Elasticsearch não está acessível - não é possível verificar índices"
        fi
    fi
}

# Função para confirmar ação
confirm_action() {
    if [[ "$FORCE_MODE" == true ]]; then
        return 0
    fi
    
    echo -e "\n${YELLOW}⚠️  Esta ação irá limpar os logs permanentemente!${NC}"
    read -p "Deseja continuar? (s/N): " confirm
    
    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        echo -e "${YELLOW}Operação cancelada pelo usuário${NC}"
        exit 0
    fi
}

# Função para parar serviços Morpheus
stop_morpheus_services() {
    echo -e "${BLUE}Parando serviços do Morpheus...${NC}"
    
    if [[ "$DRY_RUN" == false ]]; then
        morpheus-ctl stop
        
        # Aguardar serviços pararem
        local timeout=60
        local count=0
        while [[ $count -lt $timeout ]]; do
            if ! morpheus-ctl status | grep -q "run:"; then
                break
            fi
            sleep 2
            count=$((count + 2))
        done
        
        if [[ $count -ge $timeout ]]; then
            echo -e "${YELLOW}Aviso: Alguns serviços podem ainda estar rodando${NC}"
        else
            echo -e "${GREEN}Serviços parados com sucesso${NC}"
        fi
    else
        echo -e "${YELLOW}[DRY-RUN] morpheus-ctl stop${NC}"
    fi
}

# Função para iniciar serviços Morpheus
start_morpheus_services() {
    echo -e "${BLUE}Iniciando serviços do Morpheus...${NC}"
    
    if [[ "$DRY_RUN" == false ]]; then
        morpheus-ctl start
        echo -e "${GREEN}Serviços iniciados${NC}"
        echo -e "${CYAN}Use 'morpheus-ctl tail morpheus-ui' para monitorar a inicialização${NC}"
    else
        echo -e "${YELLOW}[DRY-RUN] morpheus-ctl start${NC}"
    fi
}

# Função para limpar logs de sistema
clean_system_logs() {
    echo -e "\n${BLUE}=== LIMPANDO LOGS DE SISTEMA ===${NC}"
    
    local services=("morpheus-ui" "elasticsearch" "mysql" "nginx" "rabbitmq" "check-server" "guacd")
    
    for service in "${services[@]}"; do
        local service_dir="$MORPHEUS_LOG_DIR/$service"
        
        if [[ -d "$service_dir" ]]; then
            echo -e "${CYAN}Limpando logs de $service...${NC}"
            
            # Truncar arquivo current
            if [[ -f "$service_dir/current" ]]; then
                if [[ "$DRY_RUN" == false ]]; then
                    truncate -s 0 "$service_dir/current"
                    echo "  ✅ current truncado"
                else
                    echo -e "${YELLOW}  [DRY-RUN] truncate -s 0 $service_dir/current${NC}"
                fi
            fi
            
            # Remover arquivos arquivados
            local archived_files=$(find "$service_dir" -type f \( -name "*.log.*" -o -name "@*" \) 2>/dev/null)
            if [[ -n "$archived_files" ]]; then
                local count=$(echo "$archived_files" | wc -l)
                if [[ "$DRY_RUN" == false ]]; then
                    echo "$archived_files" | xargs rm -f
                    echo "  ✅ $count arquivo(s) arquivado(s) removido(s)"
                else
                    echo -e "${YELLOW}  [DRY-RUN] $count arquivo(s) arquivado(s) seriam removidos${NC}"
                fi
            fi
        else
            echo -e "${YELLOW}  ⚠️  Diretório $service não encontrado${NC}"
        fi
    done
    
    echo -e "${GREEN}Limpeza de logs de sistema concluída${NC}"
}

# Função para limpar logs do Elasticsearch
clean_elasticsearch_logs() {
    echo -e "\n${BLUE}=== LIMPANDO LOGS DO ELASTICSEARCH ===${NC}"
    
    # Verificar se elasticsearch está acessível
    if ! curl -s "localhost:9200/_cluster/health" &>/dev/null; then
        echo -e "${YELLOW}⚠️  Elasticsearch não está acessível - pulando limpeza${NC}"
        return 0
    fi
    
    # Listar índices morpheus
    local indices=$(curl -s "localhost:9200/_cat/indices/morpheus-*?h=index" 2>/dev/null | grep -v "^$")
    
    if [[ -n "$indices" ]]; then
        local count=$(echo "$indices" | wc -l)
        echo -e "${CYAN}Removendo $count índice(s) do Elasticsearch...${NC}"
        
        if [[ "$DRY_RUN" == false ]]; then
            # Remover todos os índices morpheus-*
            curl -s -X DELETE "localhost:9200/morpheus-*" &>/dev/null
            
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}  ✅ Índices removidos com sucesso${NC}"
            else
                echo -e "${RED}  ❌ Erro ao remover índices${NC}"
            fi
        else
            echo -e "${YELLOW}  [DRY-RUN] curl -X DELETE localhost:9200/morpheus-*${NC}"
            echo "$indices" | while read -r index; do
                echo -e "${YELLOW}    - $index${NC}"
            done
        fi
    else
        echo -e "${GREEN}  ✅ Nenhum índice morpheus-* encontrado${NC}"
    fi
}

# Função para mostrar resumo final
show_summary() {
    echo -e "\n${GREEN}=== RESUMO DA LIMPEZA ===${NC}"
    
    if [[ "$CLEAN_SYSTEM" == true ]]; then
        local system_size=$(calculate_log_size "$MORPHEUS_LOG_DIR")
        echo -e "${GREEN}✅ Logs de sistema limpos - Tamanho atual: $system_size${NC}"
    fi
    
    if [[ "$CLEAN_ELASTICSEARCH" == true ]]; then
        echo -e "${GREEN}✅ Logs do Elasticsearch limpos${NC}"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "\n${YELLOW}ℹ️  Esta foi uma execução de teste (dry-run)${NC}"
        echo -e "${YELLOW}   Execute novamente sem --dry-run para aplicar as mudanças${NC}"
    else
        echo -e "\n${CYAN}ℹ️  Aguarde a inicialização completa dos serviços antes de acessar a UI${NC}"
    fi
}

# Função principal
main() {
    check_permissions
    check_morpheus_installation
    
    # Parse dos argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                CLEAN_SYSTEM=true
                CLEAN_ELASTICSEARCH=true
                shift
                ;;
            --system-only)
                CLEAN_SYSTEM=true
                shift
                ;;
            --elasticsearch-only)
                CLEAN_ELASTICSEARCH=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE_MODE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Erro: Opção desconhecida '$1'${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validar se pelo menos uma opção de limpeza foi selecionada
    if [[ "$CLEAN_SYSTEM" == false && "$CLEAN_ELASTICSEARCH" == false ]]; then
        echo -e "${RED}Erro: Especifique o que limpar (--all, --system-only, ou --elasticsearch-only)${NC}"
        show_help
        exit 1
    fi
    
    echo -e "${BLUE}=== LIMPEZA DE LOGS DO MORPHEUS DATA ENTERPRISE ===${NC}"
    
    # Mostrar análise dos arquivos
    list_files_to_clean
    
    # Confirmar ação se não for dry-run
    if [[ "$DRY_RUN" == false ]]; then
        confirm_action
    fi
    
    # Parar serviços se necessário
    if [[ "$CLEAN_SYSTEM" == true && "$DRY_RUN" == false ]]; then
        stop_morpheus_services
    fi
    
    # Executar limpeza
    if [[ "$CLEAN_SYSTEM" == true ]]; then
        clean_system_logs
    fi
    
    if [[ "$CLEAN_ELASTICSEARCH" == true ]]; then
        clean_elasticsearch_logs
    fi
    
    # Reiniciar serviços se necessário
    if [[ "$CLEAN_SYSTEM" == true && "$DRY_RUN" == false ]]; then
        start_morpheus_services
    fi
    
    # Mostrar resumo
    show_summary
}

# Executar função principal
main "$@"
