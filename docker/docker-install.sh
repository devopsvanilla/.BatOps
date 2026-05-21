#!/bin/bash
set -euo pipefail

# Atualiza lista de pacotes
sudo apt-get update -y

# Remove versões antigas do Docker, se existirem
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true

# Instala pacotes necessários
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Adiciona chave GPG oficial da Docker
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Adiciona repositório oficial da Docker
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Atualiza lista de pacotes novamente
sudo apt-get update -y

# Instala Docker Engine, CLI e containerd
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verifica instalação
docker --version
docker compose version

# Opcional: adiciona usuário atual ao grupo docker (evita usar sudo)
sudo usermod -aG docker $USER
echo "⚠️ Você precisa reiniciar a sessão para usar o Docker sem sudo."
