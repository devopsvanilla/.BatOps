#!/bin/bash

#================================================================
# Script: list-ports-and-firewall.sh
# Descrição: Lista portas em uso e regras de firewall no Ubuntu
# Autor: DevOps Vanilla
# Data: $(date)
#================================================================

# Cores para formatação
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Função para exibir cabeçalho
show_header() {
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}           RELATÓRIO DE PORTAS E FIREWALL - UBUNTU${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo ""
}

# Função para listar portas em uso
list_open_ports() {
    echo -e "${GREEN}🔍 PORTAS EM USO NO SISTEMA${NC}"
    echo -e "${CYAN}================================================================${NC}"
    
    # Cabeçalho da tabela
    printf "%-8s %-10s %-10s %-50s\n" "PORTA" "PROTOCOLO" "PID" "CAMINHO DO PROCESSO"
    echo "------------------------------------------------------------------------"
    
    # Lista portas TCP
    echo -e "${YELLOW}📡 Portas TCP:${NC}"
    netstat -tlnp 2>/dev/null | grep LISTEN | while read line; do
        # Extrai informações da linha
        proto=$(echo $line | awk '{print $1}')
        address=$(echo $line | awk '{print $4}')
        pid_program=$(echo $line | awk '{print $7}')
        
        # Extrai a porta do endereço
        port=$(echo $address | sed 's/.*://')
        
        # Extrai PID e nome do programa
        if [[ "$pid_program" != "-" && "$pid_program" != "" ]]; then
            pid=$(echo $pid_program | cut -d'/' -f1)
            program=$(echo $pid_program | cut -d'/' -f2)
            
            # Obtém o caminho completo do processo
            if [[ "$pid" =~ ^[0-9]+$ ]]; then
                process_path=$(readlink -f /proc/$pid/exe 2>/dev/null || echo "N/A")
            else
                process_path="N/A"
            fi
        else
            pid="N/A"
            program="N/A"
            process_path="N/A"
        fi
        
        printf "%-8s %-10s %-10s %-50s\n" "$port" "$proto" "$pid" "$process_path"
    done
    
    echo ""
    
    # Lista portas UDP
    echo -e "${YELLOW}📡 Portas UDP:${NC}"
    netstat -ulnp 2>/dev/null | tail -n +3 | while read line; do
        # Extrai informações da linha
        proto=$(echo $line | awk '{print $1}')
        address=$(echo $line | awk '{print $4}')
        pid_program=$(echo $line | awk '{print $6}')
        
        # Extrai a porta do endereço
        port=$(echo $address | sed 's/.*://')
        
        # Extrai PID e nome do programa
        if [[ "$pid_program" != "-" && "$pid_program" != "" ]]; then
            pid=$(echo $pid_program | cut -d'/' -f1)
            program=$(echo $pid_program | cut -d'/' -f2)
            
            # Obtém o caminho completo do processo
            if [[ "$pid" =~ ^[0-9]+$ ]]; then
                process_path=$(readlink -f /proc/$pid/exe 2>/dev/null || echo "N/A")
            else
                process_path="N/A"
            fi
        else
            pid="N/A"
            program="N/A"
            process_path="N/A"
        fi
        
        printf "%-8s %-10s %-10s %-50s\n" "$port" "$proto" "$pid" "$process_path"
    done
    
    echo ""
}

# Função para listar informações do firewall UFW
list_firewall_status() {
    echo -e "${GREEN}🔥 STATUS DO FIREWALL (UFW)${NC}"
    echo -e "${CYAN}================================================================${NC}"
    
    # Verifica se o UFW está instalado
    if ! command -v ufw &> /dev/null; then
        echo -e "${RED}❌ UFW não está instalado no sistema${NC}"
        return 1
    fi
    
    # Status do UFW
    echo -e "${YELLOW}📊 Status do UFW:${NC}"
    ufw status verbose 2>/dev/null || echo -e "${RED}❌ Erro ao obter status do UFW (execute como root/sudo)${NC}"
    
    echo ""
    
    # Regras numeradas
    echo -e "${YELLOW}📋 Regras do UFW (numeradas):${NC}"
    ufw status numbered 2>/dev/null || echo -e "${RED}❌ Erro ao obter regras do UFW (execute como root/sudo)${NC}"
    
    echo ""
}

# Função para mostrar portas bloqueadas especificamente
list_blocked_ports() {
    echo -e "${GREEN}🚫 ANÁLISE DE PORTAS BLOQUEADAS${NC}"
    echo -e "${CYAN}================================================================${NC}"
    
    if command -v ufw &> /dev/null; then
        echo -e "${YELLOW}🔍 Regras de DENY no UFW:${NC}"
        ufw status | grep -i "deny" 2>/dev/null || echo "Nenhuma regra de DENY encontrada"
        
        echo ""
        echo -e "${YELLOW}🔍 Política padrão do UFW:${NC}"
        ufw status verbose 2>/dev/null | grep -i "default" || echo -e "${RED}❌ Execute como root/sudo para ver políticas padrão${NC}"
    else
        echo -e "${RED}❌ UFW não disponível${NC}"
    fi
    
    echo ""
    
    # Verifica iptables diretamente
    echo -e "${YELLOW}🔍 Regras do iptables (DROP/REJECT):${NC}"
    if command -v iptables &> /dev/null; then
        iptables -L -n 2>/dev/null | grep -E "(DROP|REJECT)" || echo -e "${RED}❌ Execute como root/sudo para ver regras do iptables${NC}"
    else
        echo -e "${RED}❌ iptables não disponível${NC}"
    fi
    
    echo ""
}

# Função para mostrar resumo
show_summary() {
    echo -e "${GREEN}📊 RESUMO${NC}"
    echo -e "${CYAN}================================================================${NC}"
    
    # Conta portas TCP
    tcp_count=$(netstat -tln 2>/dev/null | grep LISTEN | wc -l)
    echo -e "${YELLOW}🔢 Total de portas TCP em uso: ${tcp_count}${NC}"
    
    # Conta portas UDP
    udp_count=$(netstat -uln 2>/dev/null | tail -n +3 | wc -l)
    echo -e "${YELLOW}🔢 Total de portas UDP em uso: ${udp_count}${NC}"
    
    # Status do firewall
    if command -v ufw &> /dev/null; then
        ufw_status=$(ufw status 2>/dev/null | head -1 | awk '{print $2}' || echo "desconhecido")
        echo -e "${YELLOW}🔥 Status do UFW: ${ufw_status}${NC}"
    else
        echo -e "${YELLOW}🔥 UFW: não instalado${NC}"
    fi
    
    echo ""
}

# Função principal
main() {
    # Verifica se está sendo executado com privilégios adequados
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}⚠️  Aviso: Execute como root/sudo para informações completas do firewall${NC}"
        echo ""
    fi
    
    show_header
    list_open_ports
    list_firewall_status
    list_blocked_ports
    show_summary
    
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}                    FIM DO RELATÓRIO${NC}"
    echo -e "${BLUE}================================================================${NC}"
}

# Executa o script
main "$@"