#!/bin/bash

###############################################################################
# Script: run-portainer.sh
# Descrição: Inicia o Portainer com Docker Compose
# Uso: ./run-portainer.sh [start|stop|restart|logs|status]
###############################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Diretório de scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND="${1:-start}"

# Cores para tabelas
print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
}

print_status() {
    local status=$1
    if [ "$status" == "running" ]; then
        echo -e "${GREEN}[✓] $2${NC}"
    elif [ "$status" == "warning" ]; then
        echo -e "${YELLOW}[!] $2${NC}"
    else
        echo -e "${RED}[✗] $2${NC}"
    fi
}

# Verificar se certificados existem
check_certificates() {
    if [ ! -f "$SCRIPT_DIR/certs/portainer.crt" ] || [ ! -f "$SCRIPT_DIR/certs/portainer.key" ]; then
        print_status "error" "Certificados não encontrados!"
        echo ""
        echo "Execute primeiro: bash $SCRIPT_DIR/setup-portainer.sh"
        exit 1
    fi
}

# Detectar comando Docker Compose
get_docker_compose_cmd() {
    if docker compose version &> /dev/null 2>&1; then
        echo "docker compose"
    elif command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        echo ""
    fi
}

DOCKER_COMPOSE=$(get_docker_compose_cmd)
if [ -z "$DOCKER_COMPOSE" ]; then
    print_status "error" "Docker Compose não encontrado"
    exit 1
fi

case "$COMMAND" in
    start)
        print_header "Iniciando Portainer"
        echo ""
        check_certificates
        
        echo -e "${YELLOW}[*]${NC} Iniciando containers..."
        cd "$SCRIPT_DIR"
        $DOCKER_COMPOSE up -d
        
        echo ""
        echo -e "${YELLOW}[*]${NC} Aguardando containers ficarem prontos..."
        sleep 3
        
        # Verificar status
        if $DOCKER_COMPOSE ps portainer | grep -q "Up"; then
            print_status "running" "Portainer iniciado com sucesso"
        else
            print_status "error" "Falha ao iniciar Portainer"
            $DOCKER_COMPOSE logs portainer
            exit 1
        fi
        
        echo ""
        echo -e "${BLUE}Informações de Acesso:${NC}"
        echo "  URL: https://portainer.local"
        echo "  Interface web: https://portainer.local:9443"
        echo "  API: https://portainer.local/api"
        echo ""
        echo -e "${YELLOW}[!]${NC} Primeira acesso:"
        echo "    1. Crie uma conta administratora"
        echo "    2. Conecte o endpoint Docker local"
        echo "    3. Comece a gerenciar containers!"
        echo ""
        ;;
    
    stop)
        print_header "Parando Portainer"
        echo ""
        cd "$SCRIPT_DIR"
        if $DOCKER_COMPOSE ps | grep -q "portainer.*Up"; then
            echo -e "${YELLOW}[*]${NC} Parando containers..."
            $DOCKER_COMPOSE down
            print_status "running" "Portainer parado"
        else
            print_status "warning" "Portainer não está rodando"
        fi
        echo ""
        ;;
    
    restart)
        print_header "Reiniciando Portainer"
        echo ""
        check_certificates
        cd "$SCRIPT_DIR"
        echo -e "${YELLOW}[*]${NC} Reiniciando containers..."
        $DOCKER_COMPOSE restart
        
        echo ""
        echo -e "${YELLOW}[*]${NC} Aguardando containers ficarem prontos..."
        sleep 3
        
        if $DOCKER_COMPOSE ps portainer | grep -q "Up"; then
            print_status "running" "Portainer reiniciado com sucesso"
            echo "  Acesse: https://portainer.local"
        else
            print_status "error" "Falha ao reiniciar Portainer"
            $DOCKER_COMPOSE logs portainer
            exit 1
        fi
        echo ""
        ;;
    
    logs)
        print_header "Logs do Portainer"
        echo ""
        cd "$SCRIPT_DIR"
        $DOCKER_COMPOSE logs -f portainer
        ;;
    
    status)
        print_header "Status do Portainer"
        echo ""
        cd "$SCRIPT_DIR"
        
        echo -e "${BLUE}Containers:${NC}"
        if $DOCKER_COMPOSE ps | grep -q "portainer"; then
            $DOCKER_COMPOSE ps
        else
            print_status "error" "Nenhum container ativo"
        fi
        
        echo ""
        echo -e "${BLUE}Volumes:${NC}"
        docker volume ls | grep portainer || echo "  Nenhum volume encontrado"
        
        echo ""
        echo -e "${BLUE}Rede:${NC}"
        docker network ls | grep portainer || echo "  Nenhuma rede encontrada"
        
        echo ""
        ;;
    
    *)
        echo -e "${BLUE}Portainer Manager${NC}"
        echo ""
        echo "Uso: $0 [command]"
        echo ""
        echo "Comandos disponíveis:"
        echo "  start     - Inicia o Portainer"
        echo "  stop      - Para o Portainer"
        echo "  restart   - Reinicia o Portainer"
        echo "  logs      - Mostra os logs (Ctrl+C para sair)"
        echo "  status    - Mostra o status dos containers"
        echo ""
        echo "Exemplos:"
        echo "  $0 start"
        echo "  $0 logs"
        echo "  $0 status"
        echo ""
        exit 1
        ;;
esac
