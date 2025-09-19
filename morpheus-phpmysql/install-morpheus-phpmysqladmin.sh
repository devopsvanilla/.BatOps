#!/bin/bash

# Cores para saída colorida
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
NC="\033[0m" # Sem cor

# Funções para mensagens coloridas
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
step() { echo -e "${PURPLE}🔧 $1${NC}"; }

# Verifica se o script está sendo executado com sudo
if [ "$EUID" -ne 0 ]; then
  error "Este script precisa ser executado com sudo para acessar arquivos protegidos."
  echo -e "${CYAN}💡 Por favor, execute: ${YELLOW}sudo $0 $*${NC}"
  exit 1
fi

echo -e "${CYAN}🚀 === Morpheus phpMyAdmin Setup ===${NC}\n"

# Pergunta a porta para o MySQL
step "Configurando porta do MySQL..."
echo -e "${BLUE}🗄️  Em que porta o MySQL do Morpheus está exposto?${NC}"
read -rp "Digite a porta (default: 3306): " INPUT_MYSQL_PORT
MYSQL_PORT=${INPUT_MYSQL_PORT:-3306}

# Verifica se a porta é um número válido
if ! [[ "$MYSQL_PORT" =~ ^[0-9]+$ ]] || [ "$MYSQL_PORT" -lt 1024 ] || [ "$MYSQL_PORT" -gt 65535 ]; then
  warn "Porta inválida. Usando porta padrão 3306."
  MYSQL_PORT=3306
fi

info "Porta do MySQL selecionada: $MYSQL_PORT"

# Pergunta a porta para expor o phpMyAdmin
step "Configurando porta de acesso do phpMyAdmin..."
echo -e "${BLUE}🌐 Em que porta deseja expor o phpMyAdmin?${NC}"
read -rp "Digite a porta (default: 8306): " INPUT_PMA_PORT
PMA_PORT=${INPUT_PMA_PORT:-8306}

# Verifica se a porta é um número válido
if ! [[ "$PMA_PORT" =~ ^[0-9]+$ ]] || [ "$PMA_PORT" -lt 1024 ] || [ "$PMA_PORT" -gt 65535 ]; then
  warn "Porta inválida. Usando porta padrão 8306."
  PMA_PORT=8306
fi

info "Porta do phpMyAdmin selecionada: $PMA_PORT"

# Pergunta o usuário MySQL para conexão
step "Configurando usuário MySQL..."
echo -e "${BLUE}👤 Qual usuário MySQL deseja usar para o phpMyAdmin?${NC}"
read -rp "Digite o usuário (default: root): " INPUT_USER
PMA_USER=${INPUT_USER:-root}
info "Usuário MySQL selecionado: $PMA_USER"

# Verifica se Docker está instalado
step "Verificando se Docker está instalado..."
if ! command -v docker &> /dev/null
then
  warn "Docker não encontrado. Instalando..."
  apt update
  apt install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt update
  apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  success "Docker instalado com sucesso!"
else
  success "Docker já está instalado!"
fi

# Verifica se grupo docker existe
step "Verificando grupo docker..."
if ! getent group docker > /dev/null; then
  info "Criando grupo docker..."
  groupadd docker
  success "Grupo docker criado!"
else
  success "Grupo docker já existe!"
fi

# Adiciona usuário ao grupo docker
step "Configurando permissões do usuário..."
if [ -n "$SUDO_USER" ]; then
  usermod -aG docker "$SUDO_USER"
  success "Usuário $SUDO_USER adicionado ao grupo docker!"
else
  warn "SUDO_USER não detectado, usando root como fallback"
  usermod -aG docker root
fi

# Obtém senha do MySQL "root_password" do Morpheus
step "Obtendo credenciais do MySQL root_password do Morpheus..."
if [ -f "/etc/morpheus/morpheus-secrets.json" ]; then
  if [ -r "/etc/morpheus/morpheus-secrets.json" ]; then
    PASS_MYSQL=$(sed -n 's/.*"root_password" *: *"\([^"]*\)".*/\1/p' /etc/morpheus/morpheus-secrets.json)
    if [ -n "$PASS_MYSQL" ]; then
      success "Senha do MySQL obtida com sucesso!"
    else
      error "Erro ao extrair senha do MySQL root_password do arquivo!"
      exit 1
    fi
  else
    error "Sem permissão para ler /etc/morpheus/morpheus-secrets.json!"
    exit 1
  fi
else
  error "Arquivo /etc/morpheus/morpheus-secrets.json não encontrado!"
  echo -e "   Certifique-se de que o Morpheus está instalado e configurado."
  exit 1
fi

# Configurar MySQL embedded do Morpheus para aceitar conexões externas
step "Configurando MySQL embedded do Morpheus para conexões externas..."
MORPHEUS_MYSQL_CNF="/opt/morpheus/embedded/mysql/my.cnf"

if [ -f "$MORPHEUS_MYSQL_CNF" ]; then
  # Verificar configuração atual do bind-address
  CURRENT_BIND=$(grep "bind-address" $MORPHEUS_MYSQL_CNF 2>/dev/null || echo "")
  
  if [[ "$CURRENT_BIND" =~ "127.0.0.1" ]]; then
    info "MySQL embedded configurado apenas para localhost. Alterando para aceitar conexões externas..."
    
    # Fazer backup da configuração
    cp $MORPHEUS_MYSQL_CNF ${MORPHEUS_MYSQL_CNF}.backup.$(date +%Y%m%d_%H%M%S)
    
    # Alterar bind-address para 0.0.0.0
    sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' $MORPHEUS_MYSQL_CNF
    
    # Reiniciar serviços do Morpheus
    info "Reiniciando serviços do Morpheus..."
    systemctl restart morpheus-ui morpheus-app
    
    # Aguardar reinicialização
    sleep 10
    
    # Verificar se MySQL reiniciou corretamente
    if /opt/morpheus/embedded/mysql/bin/mysql -h 127.0.0.1 -P 3306 -u root -p"$PASS_MYSQL" -e "SELECT 1;" >/dev/null 2>&1; then
      success "MySQL embedded reconfigurado para aceitar conexões externas!"
    else
      error "Erro ao reiniciar MySQL embedded. Restaurando backup..."
      mv ${MORPHEUS_MYSQL_CNF}.backup.* $MORPHEUS_MYSQL_CNF
      systemctl restart morpheus-ui morpheus-app
      exit 1
    fi
  else
    success "MySQL embedded já está configurado para aceitar conexões externas!"
  fi
else
  error "Arquivo de configuração do MySQL embedded não encontrado: $MORPHEUS_MYSQL_CNF"
  exit 1
fi

# Descobrir IP do host para usar no docker-compose
step "Detectando IP do host..."
HOST_IP=$(ip addr show | grep "inet 192.168" | head -1 | awk '{print $2}' | cut -d/ -f1)
if [ -z "$HOST_IP" ]; then
  HOST_IP=$(ip addr show | grep "inet 10\." | head -1 | awk '{print $2}' | cut -d/ -f1)
fi
if [ -z "$HOST_IP" ]; then
  HOST_IP=$(ip addr show | grep "inet 172\." | head -1 | awk '{print $2}' | cut -d/ -f1)
fi
if [ -z "$HOST_IP" ]; then
  HOST_IP="127.0.0.1"
fi

info "IP do host detectado: $HOST_IP"

# Verifica se docker-compose.yml existe
step "Verificando arquivo docker-compose.yml..."
if [ ! -f "docker-compose.yml" ]; then
  error "Arquivo docker-compose.yml não encontrado no diretório atual!"
  echo -e "${YELLOW}   💡 Certifique-se de que o arquivo docker-compose.yml está presente.${NC}"
  exit 1
else
  success "Arquivo docker-compose.yml encontrado!"
fi

# Cria arquivo .env com todas as configurações
step "Criando arquivo de configuração .env..."
cat > .env <<EOF
# Configuração do phpMyAdmin para Morpheus Data
# CONFIGURAÇÕES DO PROMPT - ESTAS TÊM PRIORIDADE
PMA_PORT=$PMA_PORT
PMA_USER=$PMA_USER  
MYSQL_PORT=$MYSQL_PORT
HOST_IP=$HOST_IP
EOF

success "Arquivo .env atualizado com as configurações do prompt:"
echo -e "   • Porta phpMyAdmin: ${CYAN}$PMA_PORT${NC}"
echo -e "   • Usuário MySQL: ${CYAN}$PMA_USER${NC}"
echo -e "   • Porta MySQL: ${CYAN}$MYSQL_PORT${NC}"
echo -e "   • IP do Host: ${CYAN}$HOST_IP${NC}"

# Exporta variáveis para docker compose
export PASS_MYSQL="$PASS_MYSQL"
export PMA_PORT="$PMA_PORT" 
export PMA_USER="$PMA_USER"
export MYSQL_PORT="$MYSQL_PORT"
export HOST_IP="$HOST_IP"

# Confirma variáveis exportadas
info "Variáveis confirmadas:"
echo -e "   • PASS_MYSQL: ${PASS_MYSQL:0:4}... ✅"
echo -e "   • PMA_PORT: $PMA_PORT ✅" 
echo -e "   • PMA_USER: $PMA_USER ✅"
echo -e "   • MYSQL_PORT: $MYSQL_PORT ✅"
echo -e "   • HOST_IP: $HOST_IP ✅"

# Para containers existentes e recria forçadamente
step "Parando containers existentes..."
docker compose down --remove-orphans 2>/dev/null || true

# Aguarda um momento
sleep 2

step "Implantando stack com configurações do prompt..."
# FORÇA recriação completa respeitando as variáveis do prompt
docker compose up -d --force-recreate --remove-orphans

# Aguarda container ficar pronto
step "Aguardando container ficar pronto..."
sleep 5

# Verifica se está rodando na porta correta
step "Verificando configuração final..."
CONTAINER_PORT=$(docker port morpheus-phpmyadmin | grep -o "0.0.0.0:[0-9]*" | cut -d: -f2)

if [ "$CONTAINER_PORT" = "$PMA_PORT" ]; then
  success "✅ Container rodando na porta CORRETA: $PMA_PORT"
else
  warn "⚠️  Container na porta $CONTAINER_PORT, esperado $PMA_PORT"
fi

# Testar conectividade final
step "Testando conectividade final..."
if /opt/morpheus/embedded/mysql/bin/mysql -h "$HOST_IP" -P "$MYSQL_PORT" -u "$PMA_USER" -p"$PASS_MYSQL" -e "SELECT 'Teste OK!' AS Status;" >/dev/null 2>&1; then
  success "✅ Conectividade MySQL externa confirmada!"
else
  warn "⚠️  Problema na conectividade MySQL externa"
fi

# Resumo final
echo -e "\n${CYAN}📋 === RESUMO DA EXECUÇÃO ===${NC}"
echo -e "${GREEN}✨ Processo concluído!${NC}\n"

echo -e "⚙️  ${BLUE}Configurações Aplicadas (do prompt):${NC}"
echo -e "   • Porta phpMyAdmin: ${CYAN}$PMA_PORT${NC}"
echo -e "   • Usuário MySQL: ${CYAN}$PMA_USER${NC}"
echo -e "   • Porta MySQL: ${CYAN}$MYSQL_PORT${NC}"
echo -e "   • IP do Host: ${CYAN}$HOST_IP${NC}"

echo -e "\n🌐 ${BLUE}Acesso ao phpMyAdmin:${NC}"
echo -e "   • URL: ${CYAN}http://$HOST_IP:$PMA_PORT${NC}"
echo -e "   • Usuário: ${YELLOW}$PMA_USER${NC}"
echo -e "   • Senha: ${YELLOW}[Extraída automaticamente do Morpheus]${NC}"

echo -e "\n🔧 ${BLUE}Comandos Úteis:${NC}"
echo -e "   • Ver logs: ${CYAN}docker compose logs -f${NC}"
echo -e "   • Verificar porta: ${CYAN}docker port morpheus-phpmyadmin${NC}"
echo -e "   • Parar: ${CYAN}docker compose down${NC}"

echo -e "\n${YELLOW}⚠️  IMPORTANTE:${NC}"
echo -e "   • MySQL embedded do Morpheus foi reconfigurado para aceitar conexões externas"
echo -e "   • Backup da configuração original foi criado"
echo -e "   • Faça logout/login para aplicar as permissões do Docker"

echo -e "\n${GREEN}🎉 phpMyAdmin configurado na porta $PMA_PORT conforme solicitado!${NC}"
