#!/bin/bash

################################################################################
# Script para limpeza de logs do Morpheus Data Enterprise (Versão Segura)
################################################################################
#
# DESCRIÇÃO:
#   Este script limpa os logs do sistema Morpheus Data Enterprise de forma
#   segura, removendo apenas arquivos arquivados e mantendo os arquivos
#   ativos (current) intactos para evitar corrupção do supervise.
#
# AUTOR: Script automatizado
# VERSÃO: 2.0 - Versão Segura
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
#   sudo ./morpheus-log-cleanup-safe.sh --all
#
# Apenas logs de sistema:
#   sudo ./morpheus-log-cleanup-safe.sh --system-only
#
# Visualizar o que seria limpo:
#   sudo ./morpheus-log-cleanup-safe.sh --all --dry-run
#
# Limpeza forçada sem confirmação:
#   sudo ./morpheus-log-cleanup-safe.sh --all --force
#
################################################################################
# LOGS LIMPOS (MODO SEGURO):
################################################################################
#
# Logs de Sistema:
# - /var/log/morpheus/morpheus-ui/*.log.* (removidos)
# - /var/log/morpheus/morpheus-ui/@* (removidos)
# - /var/log/morpheus/elasticsearch/*.log.* (removidos)
# - /var/log/morpheus/mysql/*.log.* (removidos)
# - /var/log/morpheus/nginx/*.log.* (removidos)
# - /var/log/morpheus/rabbitmq/*.log.* (removidos)
# - /var/log/morpheus/check-server/*.log.* (removidos)
# - /var/log/morpheus/guacd/*.log.* (removidos)
#
# MANTIDOS INTACTOS:
# - Todos os arquivos 'current' (para evitar corrupção do supervise)
# - Processos e serviços continuam rodando normalmente
#
# Logs de Instâncias (Elasticsearch):
# - Índices morpheus-* (removidos apenas se solicitado)
#
################################################################################
# VANTAGENS DO MODO SEGURO:
################################################################################
#
# - Serviços continuam rodando durante a limpeza
# - Não há risco de corrupção do sistema supervise
# - Não há interrupção do serviço Morpheus
# - Remove arquivos desnecessários mantendo funcionalidade
# - Sem necessidade de reinicialização após limpeza
#
################################################################################
# AVISOS IMPORTANTES:
################################################################################
#
# - Este script requer permissões de root
# - Logs de instâncias são perdidos permanentemente ao limpar Elasticsearch
# - Arquivos 'current' são mantidos para estabilidade do sistema
# - Esta versão é mais segura que o truncamento de arquivos ativos
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
MAGENTA='\033[0;35m'
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
  --system-only         Limpa apenas logs de sistema (modo seguro)
  --elasticsearch-only  Limpa apenas logs/índices do Elasticsearch
  --dry-run            Mostra o que seria limpo sem executar
  --force              Executa sem confirmação interativa
  --help               Exibe esta ajuda

Modo Seguro:
  Esta versão do script NÃO para os serviços Morpheus durante a limpeza,
  evitando problemas de corrupção do supervise. Remove apenas arquivos
  arquivados, mantendo os arquivos 'current' intactos.

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

# Função para calcular tamanho de arquivos específicos
calculate_files_size() {
    local files="$1"
    if [[ -n "$files" ]]; then
        echo "$files" | xargs du -ch 2>/dev/null | tail -1 | cut -f1
    else
        echo "0"
    fi
}

# Função para verificar status dos serviços
check_services_status() {
    echo -e "${CYAN}Status atual dos serviços Morpheus:${NC}"
    
    local services_up=0
    local services_total=0
    
    if morpheus-ctl status &>/dev/null; then
        local status_output=$(morpheus-ctl status 2>/dev/null)
        while read -r line; do
            if [[ "$line" =~ ^(ok|down|fail): ]]; then
                services_total=$((services_total + 1))
                if [[ "$line" =~ ^ok:.*run: ]]; then
                    services_up=$((services_up + 1))
                    echo "  ✅ $line"
                else
                    echo "  ❌ $line"
                fi
            fi
        done <<< "$status_output"
        
        if [[ $services_up -eq $services_total && $services_total -gt 0 ]]; then
            echo -e "${GREEN}  ✅ Todos os serviços estão rodando normalmente${NC}"
            return 0
        else
            echo -e "${YELLOW}  ⚠️  $services_up de $services_total serviços rodando${NC}"
            return 1
        fi
    else
        echo -e "${RED}  ❌ Não foi possível verificar o status dos serviços${NC}"
        return 2
    fi
}

# Função para listar arquivos que seriam limpos
list_files_to_clean() {
    echo -e "${BLUE}=== ANÁLISE DE LOGS (MODO SEGURO) ===${NC}"
    
    # Verificar status dos serviços primeiro
    check_services_status
    echo ""
    
    if [[ "$CLEAN_SYSTEM" == true ]]; then
        echo -e "${CYAN}Logs de Sistema do Morpheus (apenas arquivos arquivados):${NC}"
        local total_archived_size=0
        local total_current_size=0
        
        for service in morpheus-ui elasticsearch mysql nginx rabbitmq check-server guacd; do
            local service_dir="$MORPHEUS_LOG_DIR/$service"
            if [[ -d "$service_dir" ]]; then
                local service_size=$(calculate_log_size "$service_dir")
                echo "  📁 $service/ - Tamanho total: $service_size"
                
                # Listar arquivo current (MANTIDO)
                if [[ -f "$service_dir/current" ]]; then
                    local current_size=$(du -sh "$service_dir/current" 2>/dev/null | cut -f1)
                    echo "    📄 current - $current_size ${GREEN}(MANTIDO)${NC}"
                fi
                
                # Listar arquivos arquivados (REMOVIDOS)
                local archived_files=$(find "$service_dir" -type f \( -name "*.log.*" -o -name "@*" \) -not -name "current" 2>/dev/null)
                if [[ -n "$archived_files" ]]; then
                    local archived_count=$(echo "$archived_files" | wc -l)
                    local archived_size=$(calculate_files_size "$archived_files")
                    echo "    🗂️  $archived_count arquivo(s) arquivado(s) - $archived_size ${RED}(SERÃO REMOVIDOS)${NC}"
                    
                    # Mostrar alguns exemplos se houver muitos arquivos
                    if [[ $archived_count -gt 5 ]]; then
                        echo "        Exemplos:"
                        echo "$archived_files" | head -3 | while read -r file; do
                            if [[ -n "$file" ]]; then
                                local filename=$(basename "$file")
                                local filesize=$(du -sh "$file" 2>/dev/null | cut -f1)
                                echo "        - $filename ($filesize)"
                            fi
                        done
                        if [[ $archived_count -gt 3 ]]; then
                            echo "        ... e mais $((archived_count - 3)) arquivo(s)"
                        fi
                    else
                        echo "$archived_files" | while read -r file; do
                            if [[ -n "$file" ]]; then
                                local filename=$(basename "$file")
                                local filesize=$(du -sh "$file" 2>/dev/null | cut -f1)
                                echo "        - $filename ($filesize)"
                            fi
                        done
                    fi
                else
                    echo "    ✅ Nenhum arquivo arquivado para remover"
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
                local indices_count=$(echo "$indices" | wc -l)
                echo "  📊 $indices_count índice(s) encontrado(s):"
                echo "$indices" | while read -r line; do
                    if [[ -n "$line" ]]; then
                        echo "    - $line ${RED}(SERÁ REMOVIDO)${NC}"
                    fi
                done
            else
                echo "  ✅ Nenhum índice morpheus-* encontrado"
            fi
        else
            echo "  ⚠️  Elasticsearch não está acessível - não é possível verificar índices"
        fi
    fi
    
    echo -e "\n${MAGENTA}💡 MODO SEGURO ATIVO:${NC}"
    echo -e "${MAGENTA}   • Serviços continuarão rodando durante a limpeza${NC}"
    echo -e "${MAGENTA}   • Arquivos 'current' serão mantidos intactos${NC}"
    echo -e "${MAGENTA}   • Sem risco de corrupção do supervise${NC}"
    echo -e "${MAGENTA}   • Sem necessidade de reinicialização${NC}"
}

# Função para confirmar ação
confirm_action() {
    if [[ "$FORCE_MODE" == true ]]; then
        return 0
    fi
    
    echo -e "\n${YELLOW}ℹ️  Esta ação irá remover apenas arquivos arquivados (modo seguro)${NC}"
    echo -e "${GREEN}✅ Serviços continuarão rodando normalmente${NC}"
    read -p "Deseja continuar? (s/N): " confirm
    
    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        echo -e "${YELLOW}Operação cancelada pelo usuário${NC}"
        exit 0
    fi
}

# Função para limpar logs de sistema (modo seguro)
clean_system_logs_safe() {
    echo -e "\n${BLUE}=== LIMPANDO LOGS DE SISTEMA (MODO SEGURO) ===${NC}"
    echo -e "${GREEN}ℹ️  Limpeza será feita sem parar os serviços${NC}"
    
    local services=("morpheus-ui" "elasticsearch" "mysql" "nginx" "rabbitmq" "check-server" "guacd")
    local total_files_removed=0
    local total_size_freed="0"
    
    for service in "${services[@]}"; do
        local service_dir="$MORPHEUS_LOG_DIR/$service"
        
        if [[ -d "$service_dir" ]]; then
            echo -e "${CYAN}Limpando logs arquivados de $service...${NC}"
            
            # Encontrar apenas arquivos arquivados (NÃO o current)
            local archived_files=$(find "$service_dir" -type f \( -name "*.log.*" -o -name "@*" \) -not -name "current" 2>/dev/null)
            
            if [[ -n "$archived_files" ]]; then
                local count=$(echo "$archived_files" | wc -l)
                local size_before=""
                
                if [[ "$DRY_RUN" == false ]]; then
                    # Calcular tamanho antes da remoção
                    size_before=$(calculate_files_size "$archived_files")
                    
                    # Remover arquivos
                    echo "$archived_files" | xargs rm -f 2>/dev/null
                    
                    if [[ $? -eq 0 ]]; then
                        echo "    ✅ $count arquivo(s) arquivado(s) removido(s) - $size_before liberados"
                        total_files_removed=$((total_files_removed + count))
                    else
                        echo "    ❌ Erro ao remover alguns arquivos"
                    fi
                else
                    size_before=$(calculate_files_size "$archived_files")
                    echo -e "${YELLOW}    [DRY-RUN] $count arquivo(s) arquivado(s) seriam removidos - $size_before seriam liberados${NC}"
                fi
            else
                echo "    ℹ️  Nenhum arquivo arquivado para remover"
            fi
            
            # Verificar se o arquivo current existe e está sendo usado
            if [[ -f "$service_dir/current" ]]; then
                local current_size=$(du -sh "$service_dir/current" 2>/dev/null | cut -f1)
                echo "    📄 current mantido intacto - $current_size"
            fi
        else
            echo -e "${YELLOW}  ⚠️  Diretório $service não encontrado${NC}"
        fi
    done
    
    if [[ "$DRY_RUN" == false ]]; then
        echo -e "\n${GREEN}✅ Limpeza segura concluída:${NC}"
        echo -e "${GREEN}   • $total_files_removed arquivo(s) removido(s)${NC}"
        echo -e "${GREEN}   • Serviços não foram interrompidos${NC}"
        echo -e "${GREEN}   • Sistema supervise mantido estável${NC}"
    else
        echo -e "\n${YELLOW}🔍 Simulação concluída (dry-run)${NC}"
    fi
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
            local result=$(curl -s -X DELETE "localhost:9200/morpheus-*" 2>/dev/null)
            
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}  ✅ Índices removidos com sucesso${NC}"
                echo -e "${GREEN}     Todos os logs de instâncias foram limpos${NC}"
            else
                echo -e "${RED}  ❌ Erro ao remover índices${NC}"
                echo -e "${RED}     Detalhes: $result${NC}"
            fi
        else
            echo -e "${YELLOW}  [DRY-RUN] curl -X DELETE localhost:9200/morpheus-*${NC}"
            echo "$indices" | while read -r index; do
                if [[ -n "$index" ]]; then
                    echo -e "${YELLOW}    - $index${NC}"
                fi
            done
        fi
    else
        echo -e "${GREEN}  ✅ Nenhum índice morpheus-* encontrado${NC}"
    fi
}

# Função para mostrar resumo final
show_summary() {
    echo -e "\n${GREEN}=== RESUMO DA LIMPEZA SEGURA ===${NC}"
    
    if [[ "$CLEAN_SYSTEM" == true ]]; then
        local system_size=$(calculate_log_size "$MORPHEUS_LOG_DIR")
        echo -e "${GREEN}✅ Logs de sistema limpos (modo seguro)${NC}"
        echo -e "${GREEN}   • Tamanho atual do diretório: $system_size${NC}"
        echo -e "${GREEN}   • Arquivos 'current' mantidos intactos${NC}"
        echo -e "${GREEN}   • Serviços não foram interrompidos${NC}"
    fi
    
    if [[ "$CLEAN_ELASTICSEARCH" == true ]]; then
        echo -e "${GREEN}✅ Logs do Elasticsearch limpos${NC}"
        echo -e "${GREEN}   • Todos os índices morpheus-* removidos${NC}"
    fi
    
    # Verificar status final dos serviços
    echo -e "\n${CYAN}Verificação final dos serviços:${NC}"
    if check_services_status; then
        echo -e "${GREEN}✅ Todos os serviços continuam funcionando normalmente${NC}"
    else
        echo -e "${YELLOW}⚠️  Alguns serviços podem precisar de atenção${NC}"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "\n${YELLOW}ℹ️  Esta foi uma execução de teste (dry-run)${NC}"
        echo -e "${YELLOW}   Execute novamente sem --dry-run para aplicar as mudanças${NC}"
    else
        echo -e "\n${MAGENTA}🎉 Limpeza segura concluída com sucesso!${NC}"
        echo -e "${CYAN}ℹ️  Não há necessidade de reinicializar serviços${NC}"
        echo -e "${CYAN}ℹ️  O Morpheus continua funcionando normalmente${NC}"
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
    
    echo -e "${BLUE}=== LIMPEZA SEGURA DE LOGS DO MORPHEUS DATA ENTERPRISE ===${NC}"
    echo -e "${MAGENTA}🛡️  MODO SEGURO: Serviços não serão interrompidos${NC}"
    
    # Mostrar análise dos arquivos
    list_files_to_clean
    
    # Confirmar ação se não for dry-run
    if [[ "$DRY_RUN" == false ]]; then
        confirm_action
    fi
    
    # Executar limpeza (sem parar serviços)
    if [[ "$CLEAN_SYSTEM" == true ]]; then
        clean_system_logs_safe
    fi
    
    if [[ "$CLEAN_ELASTICSEARCH" == true ]]; then
        clean_elasticsearch_logs
    fi
    
    # Mostrar resumo
    show_summary
}

# Executar função principal
main "$@"
