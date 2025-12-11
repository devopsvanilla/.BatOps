#!/bin/bash

# Script de instalação do Starship Prompt no Ubuntu
# Autor: Copilot 🤖
# Objetivo: Instalar Starship, dependências e configurar bashrc com mensagens coloridas e interativas

# Funções de cores
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
RESET="\033[0m"

echo -e "${BLUE}🚀 Bem-vindo ao instalador do Starship Prompt para Ubuntu!${RESET}"

# Confirmação inicial
read -p "👉 Deseja continuar com a instalação? (s/n): " confirm
if [[ "$confirm" != "s" ]]; then
  echo -e "${RED}❌ Instalação cancelada pelo usuário.${RESET}"
  exit 1
fi

# Atualizar pacotes
echo -e "${YELLOW}🔄 Atualizando pacotes...${RESET}"
sudo apt update && sudo apt upgrade -y

# Instalar dependências
echo -e "${YELLOW}📦 Instalando dependências necessárias...${RESET}"
sudo apt install -y curl git fonts-powerline

# Instalar Starship
echo -e "${YELLOW}🌟 Instalando Starship Prompt...${RESET}"
curl -sS https://starship.rs/install.sh | sh

# Criar diretório de configuração
echo -e "${YELLOW}📂 Criando diretório de configuração...${RESET}"
mkdir -p ~/.config

# Criar arquivo de configuração starship.toml
echo -e "${YELLOW}📝 Criando configuração inicial...${RESET}"
cat << 'EOF' > ~/.config/starship.toml
[docker_context]
symbol = "🐳 "
format = "via [$symbol$context]($style) "

[git_branch]
symbol = "🌱 "
format = "on [$symbol$branch]($style) "

[aws]
symbol = "☁️ "
format = "[$symbol($profile)(@${region})]($style) "

[azure]
symbol = "🔷 "
format = "[$symbol($subscription)(@${tenant})]($style) "
style = "blue bold"
EOF

# Configurar bashrc
echo -e "${YELLOW}⚙️ Configurando bashrc...${RESET}"
if ! grep -q 'starship init bash' ~/.bashrc; then
  echo 'eval "$(starship init bash)"' >> ~/.bashrc
fi

# Recarregar bashrc
echo -e "${YELLOW}🔄 Recarregando bashrc...${RESET}"
source ~/.bashrc

echo -e "${GREEN}✅ Instalação concluída com sucesso!${RESET}"
echo -e "${BLUE}✨ Agora seu prompt está turbinado com Docker, Git, AWS e Azure!${RESET}"