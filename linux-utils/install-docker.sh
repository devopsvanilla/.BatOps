#!/bin/bash
set -euo pipefail

echo "Verificando a instalação do Docker..."

# Verifica se o Docker já está instalado
if command -v docker &> /dev/null; then
    echo "✅ O Docker já está instalado no sistema."
else
    echo "⏳ Docker não encontrado. Iniciando a instalação oficial para a sua distribuição Linux..."

    # Baixa e executa o script oficial de instalação do Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm -f get-docker.sh

    echo "✅ Instalação do Docker concluída."
fi

# Habilitar e iniciar o serviço do Docker (se systemd estiver disponível)
if command -v systemctl &> /dev/null; then
    sudo systemctl enable docker || true
    sudo systemctl start docker || true
fi

# Verifica instalação
docker --version
if docker compose version &> /dev/null; then
    docker compose version
fi

# Opcional: adiciona usuário atual ao grupo docker (evita usar sudo)
USER_NAME=${SUDO_USER:-$USER}
if [ "$USER_NAME" != "root" ]; then
    sudo usermod -aG docker "$USER_NAME"
    echo "⚠️ O usuário '$USER_NAME' foi adicionado ao grupo 'docker'."
    echo "⚠️ Você precisa reiniciar a sessão (ou rodar 'su - $USER_NAME') para usar o Docker sem sudo."
fi
