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

# Pergunta a porta para expor o phpMyAdmin
step "Configurando porta de acesso..."
echo -e "${BLUE}🌐 Em que porta deseja expor o phpMyAdmin?${NC}"
read -p "Digite a porta (default: 8080): " INPUT_PORT
PORT=${INPUT_PORT:-8080}

# Verifica se a porta é um número válido
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1024 ] || [ "$PORT" -gt 65535 ]; then
  warn "Porta inválida. Usando porta padrão 8080."
  PORT=8080
fi

info "Porta selecionada: $PORT"

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

# Adiciona usuário ao grupo docker (usa $SUDO_USER para pegar o usuário real)
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

# Cria arquivo .env apenas com a porta (SEM senha por segurança)
step "Criando arquivo de configuração .env..."
cat > .env <<EOF
# Configurações do phpMyAdmin para Morpheus Data
# A senha é obtida dinamicamente do morpheus-secrets.json
PMA_PORT=$PORT
EOF

success "Arquivo .env criado com a porta $PORT"

# Cria arquivo docker-compose.yml que usa variáveis de ambiente
step "Criando docker-compose.yml..."
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  phpmyadmin:
    image: phpmyadmin/phpmyadmin:latest
    container_name: morpheus-phpmyadmin
    restart: unless-stopped
    ports:
      - "\${PMA_PORT}:80"
    environment:
      PMA_HOST: host.docker.internal
      PMA_PORT: 3306
      PMA_USER: morpheus
      PMA_PASSWORD: \${PASS_MYSQL}
      UPLOAD_LIMIT: 256M
      PMA_ABSOLUTE_URI: "http://localhost:\${PMA_PORT}/"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - phpmyadmin_sessions:/sessions

volumes:
  phpmyadmin_sessions:
EOF

success "Arquivo docker-compose.yml criado com variáveis de ambiente"

# Exporta variáveis para docker compose
export PASS_MYSQL="$PASS_MYSQL"
export PMA_PORT="$PORT"

info "Variáveis de ambiente configuradas para o docker-compose"

# Verifica se a stack já existe
step "Verificando se phpMyAdmin já está implantado..."
if docker ps -a --format '{{.Names}}' | grep -q '^morpheus-phpmyadmin$'; then
  warn "Container morpheus-phpmyadmin já existe!"

  if docker ps --format '{{.Names}}' | grep -q '^morpheus-phpmyadmin$'; then
    info "Container está rodando. Atualizando stack..."
    docker compose down
    docker compose pull
    docker compose up -d
    success "Stack atualizada e reiniciada com sucesso!"
    OPERATION="atualizada"
  else
    info "Container existe mas não está rodando. Iniciando..."
    docker compose up -d
    success "Stack iniciada com sucesso!"
    OPERATION="reiniciada"
  fi
else
  info "phpMyAdmin não encontrado. Implantando nova stack..."
  docker compose up -d
  success "Stack implantada com sucesso!"
  OPERATION="implantada"
fi

# Aguarda container ficar pronto
step "Aguardando container ficar pronto..."
sleep 5

# Verifica se o serviço está rodando
if docker ps --format '{{.Names}}\t{{.Status}}' | grep morpheus-phpmyadmin | grep -q "Up"; then
  success "Container está rodando corretamente!"
else
  error "Problema detectado com o container!"
  echo -e "${YELLOW}   💡 Verifique os logs com: docker compose logs${NC}"
fi

# Resumo final
echo -e "\n${CYAN}📋 === RESUMO DA EXECUÇÃO ===${NC}"
echo -e "${GREEN}✨ Processo concluído com sucesso!${NC}\n"

echo -e "📊 ${BLUE}Status da Implantação:${NC}"
echo -e "   • Docker: $(if command -v docker &> /dev/null; then echo -e "${GREEN}✅ Instalado${NC}"; else echo -e "${RED}❌ Não instalado${NC}"; fi)"
echo -e "   • Grupo Docker: $(if getent group docker > /dev/null; then echo -e "${GREEN}✅ Configurado${NC}"; else echo -e "${RED}❌ Não configurado${NC}"; fi)"
echo -e "   • Stack phpMyAdmin: ${GREEN}✅ Stack ${OPERATION}${NC}"
echo -e "   • Porta configurada: ${CYAN}$PORT${NC}"

echo -e "\n📁 ${BLUE}Arquivos Criados:${NC}"
echo -e "   • ${CYAN}.env${NC} - Configurações do ambiente (apenas porta)"
echo -e "   • ${CYAN}docker-compose.yml${NC} - Definição dos serviços"

echo -e "\n🌐 ${BLUE}Acesso ao phpMyAdmin:${NC}"
echo -e "   • URL: ${CYAN}http://localhost:$PORT${NC}"
echo -e "   • Usuário: ${YELLOW}morpheus${NC}"
echo -e "   • Senha: ${YELLOW}[Extraída automaticamente do Morpheus]${NC}"

echo -e "\n🔧 ${BLUE}Comandos Úteis:${NC}"
echo -e "   • Ver status: ${CYAN}docker compose ps${NC}"
echo -e "   • Ver logs: ${CYAN}docker compose logs -f${NC}"
echo -e "   • Parar: ${CYAN}docker compose down${NC}"
echo -e "   • Reiniciar: ${CYAN}docker compose restart${NC}"

echo -e "\n${YELLOW}⚠️  IMPORTANTE:${NC}"
echo -e "   • O usuário ${SUDO_USER:-root} foi adicionado ao grupo docker"
echo -e "   • Faça logout/login para aplicar as permissões"
echo -e "   • A senha é obtida dinamicamente do morpheus-secrets.json (não salva em arquivo)"
echo -e "   • Para executar docker compose manualmente, exporte as variáveis primeiro:\n"
echo -e "   ${CYAN}export PASS_MYSQL=\$(sudo sed -n 's/.*\"root_password\" *: *\"\([^\"]*\)\".*/\1/p' /etc/morpheus/morpheus-secrets.json)${NC}"
echo -e "   ${CYAN}export PMA_PORT=$PORT${NC}\n"

echo -e "${GREEN}🎉 Setup do phpMyAdmin concluído na porta $PORT!${NC}"
