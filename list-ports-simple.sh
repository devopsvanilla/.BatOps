#!/bin/bash

#================================================================
# Script: list-ports-simple.sh
# Descrição: Versão simplificada para listar portas em uso
# Usa 'ss' (mais moderno que netstat)
# Autor: DevOps Vanilla
#================================================================

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== PORTAS EM USO - UBUNTU ===${NC}"
echo ""

# Função para processar informações de porta com ss
list_ports_ss() {
    echo -e "${GREEN}🔍 Usando comando 'ss' (mais moderno):${NC}"
    echo ""
    printf "%-10s %-8s %-10s %-60s\n" "PROTOCOLO" "PORTA" "PID" "PROCESSO/CAMINHO"
    echo "----------------------------------------------------------------------------------------------------"
    
    # TCP
    echo -e "${YELLOW}📡 TCP:${NC}"
    ss -tlnp | grep LISTEN | while IFS= read -r line; do
        # Extrai porta
        port=$(echo "$line" | awk '{print $4}' | sed 's/.*://')
        
        # Extrai informações do processo
        process_info=$(echo "$line" | awk '{print $6}' | sed 's/users:((//' | sed 's/))//')
        
        if [[ "$process_info" != "" && "$process_info" != "-" ]]; then
            # Extrai nome do processo e PID
            process_name=$(echo "$process_info" | cut -d',' -f1 | tr -d '"')
            pid=$(echo "$process_info" | cut -d',' -f2 | grep -o '[0-9]*')
            
            # Obtém caminho do processo
            if [[ "$pid" =~ ^[0-9]+$ ]] && [[ -d "/proc/$pid" ]]; then
                process_path=$(readlink -f "/proc/$pid/exe" 2>/dev/null || echo "N/A")
                cmdline=$(cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ' | cut -c1-40)
            else
                process_path="N/A"
                cmdline="N/A"
            fi
        else
            process_name="N/A"
            pid="N/A"
            process_path="N/A"
            cmdline="N/A"
        fi
        
        printf "%-10s %-8s %-10s %-60s\n" "tcp" "$port" "$pid" "$process_path"
    done
    
    echo ""
    
    # UDP
    echo -e "${YELLOW}📡 UDP:${NC}"
    ss -ulnp | tail -n +2 | while IFS= read -r line; do
        # Extrai porta
        port=$(echo "$line" | awk '{print $4}' | sed 's/.*://')
        
        # Extrai informações do processo
        process_info=$(echo "$line" | awk '{print $6}' | sed 's/users:((//' | sed 's/))//')
        
        if [[ "$process_info" != "" && "$process_info" != "-" ]]; then
            # Extrai nome do processo e PID
            process_name=$(echo "$process_info" | cut -d',' -f1 | tr -d '"')
            pid=$(echo "$process_info" | cut -d',' -f2 | grep -o '[0-9]*')
            
            # Obtém caminho do processo
            if [[ "$pid" =~ ^[0-9]+$ ]] && [[ -d "/proc/$pid" ]]; then
                process_path=$(readlink -f "/proc/$pid/exe" 2>/dev/null || echo "N/A")
            else
                process_path="N/A"
            fi
        else
            process_name="N/A"
            pid="N/A"
            process_path="N/A"
        fi
        
        printf "%-10s %-8s %-10s %-60s\n" "udp" "$port" "$pid" "$process_path"
    done
}

# Função alternativa usando lsof
list_ports_lsof() {
    echo ""
    echo -e "${GREEN}🔍 Usando comando 'lsof' (alternativo):${NC}"
    echo ""
    printf "%-10s %-8s %-10s %-60s\n" "PROTOCOLO" "PORTA" "PID" "PROCESSO/CAMINHO"
    echo "----------------------------------------------------------------------------------------------------"
    
    if command -v lsof &> /dev/null; then
        lsof -i -P -n | grep LISTEN | while IFS= read -r line; do
            process_name=$(echo "$line" | awk '{print $1}')
            pid=$(echo "$line" | awk '{print $2}')
            port_info=$(echo "$line" | awk '{print $9}')
            
            # Extrai protocolo e porta
            if [[ "$port_info" =~ TCP ]]; then
                protocol="tcp"
                port=$(echo "$port_info" | sed 's/.*://' | sed 's/ .*//')
            else
                protocol="udp"
                port=$(echo "$port_info" | sed 's/.*://' | sed 's/ .*//')
            fi
            
            # Obtém caminho do processo
            if [[ "$pid" =~ ^[0-9]+$ ]] && [[ -d "/proc/$pid" ]]; then
                process_path=$(readlink -f "/proc/$pid/exe" 2>/dev/null || echo "N/A")
            else
                process_path="N/A"
            fi
            
            printf "%-10s %-8s %-10s %-60s\n" "$protocol" "$port" "$pid" "$process_path"
        done
    else
        echo "lsof não está disponível. Instale com: sudo apt install lsof"
    fi
}

# Verificar firewall simplificado
check_firewall_simple() {
    echo ""
    echo -e "${GREEN}🔥 STATUS DO FIREWALL${NC}"
    echo "================================"
    
    if command -v ufw &> /dev/null; then
        echo -e "${YELLOW}UFW Status:${NC}"
        ufw status 2>/dev/null || echo "Execute com sudo para ver status completo"
    else
        echo "UFW não instalado"
    fi
    
    echo ""
    echo -e "${YELLOW}Verificação rápida iptables:${NC}"
    iptables -L INPUT -n 2>/dev/null | grep -E "(DROP|REJECT|ACCEPT)" | head -5 || echo "Execute com sudo para ver iptables"
}

# Main
main() {
    if command -v ss &> /dev/null; then
        list_ports_ss
    elif command -v netstat &> /dev/null; then
        echo -e "${YELLOW}⚠️  'ss' não disponível, usando netstat...${NC}"
        echo "Considere instalar: sudo apt install iproute2"
        echo ""
    else
        echo -e "${YELLOW}⚠️  Nem 'ss' nem 'netstat' disponíveis${NC}"
        echo "Instale com: sudo apt install iproute2 net-tools"
    fi
    
    # Tentar lsof como alternativa
    list_ports_lsof
    
    # Verificar firewall
    check_firewall_simple
    
    echo ""
    echo -e "${BLUE}=== FIM DO RELATÓRIO ===${NC}"
}

# Executar
main "$@"