#!/bin/bash

###############################################################################
# Script: COMECE_AQUI.sh
# Descrição: Guia interativo para começar com o Portainer
# Uso: ./COMECE_AQUI.sh
###############################################################################

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

clear_screen() {
    clear
}

print_banner() {
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║          🐳  PORTAINER COM CERTIFICADO AUTO-ASSINADO  🐳     ║
║                                                               ║
║         Setup para WSL + Windows com DNS Customizado         ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
}

menu_principal() {
    clear_screen
    print_banner
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  MENU PRINCIPAL${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  1) 🚀 Iniciar Portainer (primeira vez)"
    echo "  2) 🔧 Configurar DNS no Windows"
    echo "  3) 📋 Ver status do Portainer"
    echo "  4) 📊 Diagnosticar problemas"
    echo "  5) 🛑 Parar Portainer"
    echo "  6) 🔄 Reiniciar Portainer"
    echo "  7) 📖 Ver logs"
    echo "  8) ❓ Ver instruções detalhadas"
    echo "  9) 🚪 Sair"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

opcao_iniciar() {
    clear_screen
    print_banner
    echo ""
    echo -e "${GREEN}[➤]${NC} Iniciando Portainer..."
    echo ""
    bash "$SCRIPT_DIR/run-portainer.sh" start
    echo ""
    read -p "Pressione ENTER para continuar..."
}

opcao_status() {
    clear_screen
    print_banner
    echo ""
    echo -e "${GREEN}[➤]${NC} Status do Portainer:"
    echo ""
    bash "$SCRIPT_DIR/run-portainer.sh" status
    echo ""
    read -p "Pressione ENTER para continuar..."
}

opcao_diagnostico() {
    clear_screen
    print_banner
    echo ""
    echo -e "${GREEN}[➤]${NC} Executando diagnóstico..."
    echo ""
    bash "$SCRIPT_DIR/diagnose-portainer.sh"
    echo ""
    read -p "Pressione ENTER para continuar..."
}

opcao_parar() {
    clear_screen
    print_banner
    echo ""
    echo -e "${YELLOW}[!]${NC} Parando Portainer..."
    echo ""
    bash "$SCRIPT_DIR/run-portainer.sh" stop
    echo ""
    read -p "Pressione ENTER para continuar..."
}

opcao_reiniciar() {
    clear_screen
    print_banner
    echo ""
    echo -e "${YELLOW}[!]${NC} Reiniciando Portainer..."
    echo ""
    bash "$SCRIPT_DIR/run-portainer.sh" restart
    echo ""
    read -p "Pressione ENTER para continuar..."
}

opcao_logs() {
    clear_screen
    print_banner
    echo ""
    echo -e "${GREEN}[➤]${NC} Logs do Portainer (Ctrl+C para sair):"
    echo ""
    bash "$SCRIPT_DIR/run-portainer.sh" logs
}

opcao_dns() {
    clear_screen
    print_banner
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  CONFIGURAR DNS NO WINDOWS${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}[!]${NC} Escolha uma opção:"
    echo ""
    echo "  1) 📋 Ver instruções PowerShell"
    echo "  2) ✏️  Ver instruções edição manual"
    echo "  3) 🔧 Ver instruções script PowerShell"
    echo "  4) ◀️  Voltar ao menu"
    echo ""
    read -p "Opção: " -n 1 -r
    echo ""
    
    case "$REPLY" in
        1)
            clear_screen
            print_banner
            echo ""
            echo -e "${BLUE}PowerShell (Administrador):${NC}"
            echo ""
            echo 'Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "`n127.0.0.1`t`tportainer.local" -Force'
            echo ""
            echo -e "${YELLOW}[!]${NC} Execute este comando no PowerShell como Administrador"
            ;;
        2)
            clear_screen
            print_banner
            echo ""
            echo -e "${BLUE}Edição Manual:${NC}"
            echo ""
            echo "1. Abra Bloco de Notas como Administrador"
            echo "2. Vá em Arquivo → Abrir"
            echo "3. Procure por: C:\\Windows\\System32\\drivers\\etc\\hosts"
            echo "4. Adicione a linha: 127.0.0.1    portainer.local"
            echo "5. Salve o arquivo"
            ;;
        3)
            bash "$SCRIPT_DIR/add-to-windows-hosts.sh" | head -50
            ;;
    esac
    
    echo ""
    read -p "Pressione ENTER para continuar..."
}

opcao_instrucoes() {
    clear_screen
    print_banner
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  INSTRUÇÕES DETALHADAS${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}📌 PRIMEIRA EXECUÇÃO:${NC}"
    echo ""
    echo "  1. Opção 1 do menu: Iniciar Portainer (já foi feito no setup)"
    echo "  2. Opção 2 do menu: Configurar DNS no Windows"
    echo "  3. Acesse: https://portainer.local no navegador Windows"
    echo "  4. Crie conta administratora"
    echo ""
    
    echo -e "${CYAN}🌐 ACESSO:${NC}"
    echo ""
    echo "  URL: https://portainer.local"
    echo "  IP Local: $(hostname -I | awk '{print $1}')"
    echo "  WSL Hostname: $(hostname)"
    echo ""
    
    echo -e "${CYAN}⚙️  CERTIFICADO:${NC}"
    echo ""
    echo "  Tipo: Auto-assinado (SSL/TLS)"
    echo "  Válido até: 365 dias"
    echo "  Arquivo: certs/portainer.crt"
    echo "  Aviso: Navegador mostrará alerta de segurança (normal)"
    echo ""
    
    echo -e "${CYAN}🐳 GERENCIAR:${NC}"
    echo ""
    echo "  Iniciar:   bash run-portainer.sh start"
    echo "  Parar:     bash run-portainer.sh stop"
    echo "  Reiniciar: bash run-portainer.sh restart"
    echo "  Logs:      bash run-portainer.sh logs"
    echo "  Status:    bash run-portainer.sh status"
    echo ""
    
    echo -e "${CYAN}📁 ESTRUTURA:${NC}"
    echo ""
    echo "  docker-compose.yml      → Configuração dos containers"
    echo "  nginx.conf              → Proxy reverso"
    echo "  certs/                  → Certificados SSL"
    echo "  data/                   → Dados persistentes"
    echo ""
    
    read -p "Pressione ENTER para continuar..."
}

# Loop principal
while true; do
    menu_principal
    read -p "Selecione uma opção: " opcao
    
    case "$opcao" in
        1) opcao_iniciar ;;
        2) opcao_dns ;;
        3) opcao_status ;;
        4) opcao_diagnostico ;;
        5) opcao_parar ;;
        6) opcao_reiniciar ;;
        7) opcao_logs ;;
        8) opcao_instrucoes ;;
        9)
            clear_screen
            echo -e "${GREEN}Até logo!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Opção inválida!${NC}"
            sleep 2
            ;;
    esac
done
