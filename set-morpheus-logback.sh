#!/bin/bash

################################################################################
# Script para gerenciar níveis de log do Morpheus Data Enterprise
################################################################################
#
# DESCRIÇÃO:
#   Este script permite alterar os níveis de logging de todos os serviços do
#   Morpheus Data Enterprise e gerenciar backups das configurações.
#
# AUTOR: Script automatizado
# VERSÃO: 1.0
# DATA: 2025-09-11
#
################################################################################
# OPÇÕES DE EXECUÇÃO:
################################################################################
#
# --debug-level LEVEL
#   Altera o nível de debug para todos os serviços do Morpheus.
#   Níveis válidos: OFF, ERROR, WARN, INFO, DEBUG, TRACE
#   
#   Funcionalidade:
#   - Cria backup automático da configuração atual
#   - Modifica todos os loggers existentes no logback.xml
#   - Aplica o novo nível especificado a todos os serviços
#   - Alterações são aplicadas automaticamente em até 30 segundos
#
# --restore
#   Restaura uma configuração anterior a partir dos backups disponíveis.
#   
#   Funcionalidade:
#   - Lista todos os backups existentes de forma numerada
#   - Permite seleção interativa do backup desejado
#   - Cria backup da configuração atual antes da restauração
#   - Solicita confirmação antes de aplicar a restauração
#
# --list-backups
#   Lista todos os backups disponíveis no diretório de backup.
#   
#   Funcionalidade:
#   - Mostra nome do arquivo e data/hora formatada de cada backup
#   - Exibe os backups em ordem cronológica
#   - Informa se não há backups disponíveis
#
# --help, -h
#   Exibe a ajuda completa do script com exemplos de uso.
#
################################################################################
# EXEMPLOS DE USO:
################################################################################
#
# Definir nível DEBUG para todos os serviços:
#   sudo ./morpheus-log-manager.sh --debug-level DEBUG
#
# Definir nível INFO para todos os serviços:
#   sudo ./morpheus-log-manager.sh --debug-level INFO
#
# Listar backups disponíveis:
#   sudo ./morpheus-log-manager.sh --list-backups
#
# Restaurar configuração anterior:
#   sudo ./morpheus-log-manager.sh --restore
#
# Exibir ajuda:
#   ./morpheus-log-manager.sh --help
#
################################################################################
# REQUISITOS:
################################################################################
#
# - Permissões de root ou escrita em /opt/morpheus/conf/
# - Morpheus Data Enterprise instalado e configurado
# - Arquivo logback.xml existente em /opt/morpheus/conf/
#
################################################################################
# ARQUIVOS UTILIZADOS:
################################################################################
#
# /opt/morpheus/conf/logback.xml          - Arquivo de configuração principal
# /opt/morpheus/conf/backups/             - Diretório dos backups
# /opt/morpheus/conf/backups/logback_*.xml - Arquivos de backup com timestamp
#
################################################################################
# AVISOS IMPORTANTES:
################################################################################
#
# - Níveis DEBUG e TRACE podem gerar muitos logs e consumir espaço em disco
# - Backups são criados automaticamente antes de qualquer alteração
# - As alterações são aplicadas automaticamente pelo Morpheus (scanPeriod: 30s)
# - Em ambiente de produção, use níveis de log mais conservadores (INFO ou WARN)
#
################################################################################

# Configurações
MORPHEUS_CONFIG="/opt/morpheus/conf/logback.xml"
BACKUP_DIR="/opt/morpheus/conf/backups"
SCRIPT_NAME="$(basename "$0")"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir ajuda
show_help() {
    cat << EOF
Uso: $SCRIPT_NAME [OPÇÕES]

Opções:
  --debug-level LEVEL    Define o nível de debug para todos os serviços
                        Níveis válidos: OFF, ERROR, WARN, INFO, DEBUG, TRACE
  --restore             Restaura um backup anterior
  --list-backups        Lista todos os backups disponíveis
  --help                Exibe esta ajuda

Exemplos:
  $SCRIPT_NAME --debug-level DEBUG
  $SCRIPT_NAME --debug-level INFO
  $SCRIPT_NAME --restore
  $SCRIPT_NAME --list-backups

EOF
}

# Função para validar nível de log
validate_log_level() {
    local level="$1"
    case "$level" in
        OFF|ERROR|WARN|INFO|DEBUG|TRACE)
            return 0
            ;;
        *)
            echo -e "${RED}Erro: Nível de log inválido '$level'${NC}"
            echo -e "${YELLOW}Níveis válidos: OFF, ERROR, WARN, INFO, DEBUG, TRACE${NC}"
            return 1
            ;;
    esac
}

# Função para verificar se o arquivo existe
check_config_file() {
    if [[ ! -f "$MORPHEUS_CONFIG" ]]; then
        echo -e "${RED}Erro: Arquivo de configuração não encontrado: $MORPHEUS_CONFIG${NC}"
        echo -e "${YELLOW}Verifique se o Morpheus Data Enterprise está instalado corretamente.${NC}"
        exit 1
    fi
}

# Função para criar diretório de backup
create_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}Erro: Não foi possível criar diretório de backup: $BACKUP_DIR${NC}"
            exit 1
        fi
    fi
}

# Função para criar backup
create_backup() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$BACKUP_DIR/logback_${timestamp}.xml"
    
    echo -e "${BLUE}Criando backup da configuração atual...${NC}"
    
    cp "$MORPHEUS_CONFIG" "$backup_file"
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Backup criado com sucesso: $backup_file${NC}"
        echo "$backup_file"
    else
        echo -e "${RED}Erro ao criar backup${NC}"
        exit 1
    fi
}

# Função para listar backups
list_backups() {
    local backups=($(find "$BACKUP_DIR" -name "logback_*.xml" 2>/dev/null | sort))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo -e "${YELLOW}Nenhum backup encontrado em: $BACKUP_DIR${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Backups disponíveis:${NC}"
    for i in "${!backups[@]}"; do
        local backup_file="${backups[$i]}"
        local filename=$(basename "$backup_file")
        local timestamp=$(echo "$filename" | sed 's/logback_\(.*\)\.xml/\1/')
        local formatted_date=$(date -d "${timestamp:0:8} ${timestamp:9:2}:${timestamp:11:2}:${timestamp:13:2}" +"%d/%m/%Y %H:%M:%S" 2>/dev/null || echo "$timestamp")
        
        printf "%2d) %-25s (%s)\n" $((i+1)) "$filename" "$formatted_date"
    done
    
    return 0
}

# Função para restaurar backup
restore_backup() {
    create_backup_dir
    
    if ! list_backups; then
        return 1
    fi
    
    local backups=($(find "$BACKUP_DIR" -name "logback_*.xml" 2>/dev/null | sort))
    
    echo
    read -p "Digite o número do backup para restaurar (0 para cancelar): " choice
    
    if [[ "$choice" -eq 0 ]]; then
        echo -e "${YELLOW}Restauração cancelada${NC}"
        return 0
    fi
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#backups[@]} ]]; then
        echo -e "${RED}Erro: Seleção inválida${NC}"
        return 1
    fi
    
    local selected_backup="${backups[$((choice-1))]}"
    local filename=$(basename "$selected_backup")
    
    echo -e "${YELLOW}Você selecionou: $filename${NC}"
    read -p "Confirmar restauração? (s/N): " confirm
    
    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        echo -e "${YELLOW}Restauração cancelada${NC}"
        return 0
    fi
    
    # Criar backup da configuração atual antes de restaurar
    local current_backup=$(create_backup)
    echo -e "${BLUE}Configuração atual salva em: $(basename "$current_backup")${NC}"
    
    # Restaurar backup selecionado
    cp "$selected_backup" "$MORPHEUS_CONFIG"
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Backup restaurado com sucesso!${NC}"
        echo -e "${YELLOW}Reinicie o serviço Morpheus para aplicar as mudanças${NC}"
    else
        echo -e "${RED}Erro ao restaurar backup${NC}"
        return 1
    fi
}

# Função para alterar nível de debug
change_debug_level() {
    local new_level="$1"
    
    echo -e "${BLUE}Alterando nível de debug para: $new_level${NC}"
    
    # Criar backup antes de alterar
    create_backup_dir
    local backup_file=$(create_backup)
    
    # Fazer uma cópia temporária para trabalhar
    local temp_file=$(mktemp)
    cp "$MORPHEUS_CONFIG" "$temp_file"
    
    # Primeiro, atualizar todos os loggers existentes
    sed -i "s/level=\"\(OFF\|ERROR\|WARN\|INFO\|DEBUG\|TRACE\)\"/level=\"$new_level\"/g" "$temp_file"
    
    # Verificar se houve alterações
    if ! cmp -s "$MORPHEUS_CONFIG" "$temp_file"; then
        cp "$temp_file" "$MORPHEUS_CONFIG"
        echo -e "${GREEN}Configuração alterada com sucesso!${NC}"
        echo -e "${GREEN}Todos os loggers foram definidos para o nível: $new_level${NC}"
        echo -e "${YELLOW}As alterações serão aplicadas automaticamente em até 30 segundos${NC}"
        
        # Mostrar alguns exemplos dos loggers alterados
        echo -e "\n${BLUE}Exemplos de loggers alterados:${NC}"
        grep -n "level=\"$new_level\"" "$MORPHEUS_CONFIG" | head -5 | while read line; do
            echo "  $line"
        done
        
        if [[ "$new_level" == "DEBUG" ]] || [[ "$new_level" == "TRACE" ]]; then
            echo
            echo -e "${YELLOW}⚠️  AVISO: Níveis DEBUG e TRACE podem gerar muitos logs!${NC}"
            echo -e "${YELLOW}   Monitore o espaço em disco e considere usar níveis mais baixos em produção.${NC}"
        fi
    else
        echo -e "${YELLOW}Nenhuma alteração foi necessária - configuração já está no nível $new_level${NC}"
        # Remover backup desnecessário
        rm -f "$backup_file"
    fi
    
    rm -f "$temp_file"
}

# Função principal
main() {
    # Verificar se está rodando como root ou com permissões adequadas
    if [[ ! -w "$MORPHEUS_CONFIG" ]]; then
        echo -e "${RED}Erro: Sem permissão para modificar $MORPHEUS_CONFIG${NC}"
        echo -e "${YELLOW}Execute o script como root ou com permissões adequadas${NC}"
        exit 1
    fi
    
    # Verificar arquivo de configuração
    check_config_file
    
    # Parsing dos argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --debug-level)
                if [[ -z "$2" ]]; then
                    echo -e "${RED}Erro: --debug-level requer um nível como argumento${NC}"
                    show_help
                    exit 1
                fi
                
                if validate_log_level "$2"; then
                    change_debug_level "$2"
                    exit 0
                else
                    exit 1
                fi
                ;;
            --restore)
                restore_backup
                exit 0
                ;;
            --list-backups)
                create_backup_dir
                list_backups
                exit 0
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
    
    # Se nenhum argumento foi fornecido, mostrar ajuda
    echo -e "${YELLOW}Nenhuma opção fornecida${NC}"
    show_help
    exit 1
}

# Executar função principal
main "$@"
