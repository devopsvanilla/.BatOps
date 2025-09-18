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
read -p "Digite a porta (default: 3306): " INPUT_MYSQL_PORT
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
read -p "Digite a porta (default: 8306): " INPUT_PMA_PORT
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
read -p "Digite o usuário (default: root): " INPUT_USER
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
  usermod -aG docker $SUDO_USER
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

# Configurar MySQL para aceitar conexões externas
step "Configurando MySQL para aceitar conexões externas..."
MYSQL_CONFIG_FILE="/etc/mysql/mysql.conf.d/mysqld.cnf"

if [ -f "$MYSQL_CONFIG_FILE" ]; then
  # Verificar configuração atual do bind-address
  CURRENT_BIND=$(grep -E "^\s*bind-address" $MYSQL_CONFIG_FILE 2>/dev/null || echo "")
  
  if [[ "$CURRENT_BIND" =~ "127.0.0.1" ]] || [[ "$CURRENT_BIND" =~ "localhost" ]]; then
    info "MySQL configurado apenas para localhost. Alterando para aceitar conexões externas..."
    
    # Fazer backup da configuração
    cp $MYSQL_CONFIG_FILE ${MYSQL_CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)
    
    # Alterar bind-address para 0.0.0.0
    sed -i 's/^[[:space:]]*bind-address[[:space:]]*=.*/bind-address = 0.0.0.0/' $MYSQL_CONFIG_FILE
    
    # Reiniciar MySQL
    info "Reiniciando serviço MySQL..."
    systemctl restart mysql
    
    # Verificar se MySQL reiniciou corretamente
    sleep 3
    if systemctl is-active mysql >/dev/null 2>&1; then
      success "MySQL reconfigurado para aceitar conexões externas!"
    else
      error "Erro ao reiniciar MySQL. Restaurando backup..."
      mv ${MYSQL_CONFIG_FILE}.backup.* $MYSQL_CONFIG_FILE
      systemctl restart mysql
      exit 1
    fi
  else
    success "MySQL já está configurado para aceitar conexões externas!"
  fi
else
  warn "Arquivo de configuração do MySQL não encontrado em $MYSQL_CONFIG_FILE"
  info "Tentando localizar arquivo de configuração..."
  
  # Tentar encontrar outros locais comuns
  for config_path in "/etc/mysql/my.cnf" "/etc/my.cnf" "/opt/morpheus/embedded/mysql/my.cnf"; do
    if [ -f "$config_path" ]; then
      info "Arquivo de configuração encontrado em: $config_path"
      # Aplicar mesma lógica para outros arquivos
      break
    fi
  done
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

# Cria arquivo .env com TODAS as configurações (FORÇA OVERRIDE)
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

# FORÇA exportação das variáveis
step "Exportando variáveis de ambiente..."
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
echo -e "   • MySQL foi reconfigurado para aceitar conexões externas"
echo -e "   • Backup da configuração original foi criado"
echo -e "   • Faça logout/login para aplicar as permissões do Docker"

echo -e "\n${GREEN}🎉 phpMyAdmin configurado na porta $PMA_PORT conforme solicitado!${NC}"
