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

# Instalação opcional do Dockly
if ! command -v dockly &> /dev/null; then
    echo ""
    read -p "Deseja instalar o Dockly (dashboard CLI para Docker)? (s/N): " dockly_response || dockly_response="n"
    if [[ "$dockly_response" =~ ^[Ss]$ ]]; then
        echo "⏳ Instalando dependências de sistema para Node.js (libatomic)..."
        # Tratamento de libatomic para que o Node+Dockly funcione em qualquer disto base
        if command -v apt-get &> /dev/null; then
            sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y libatomic1 >/dev/null 2>&1 || true
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y libatomic >/dev/null 2>&1 || true
        elif command -v yum &> /dev/null; then
            sudo yum install -y libatomic >/dev/null 2>&1 || true
        fi

        echo "⏳ Instalando nvm e Node.js..."
        export NVM_DIR="$HOME/.nvm"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

        nvm install node --latest-npm
        nvm use node

        echo "⏳ Instalando Dockly..."
        npm install -g dockly
        echo "✅ Dockly instalado com sucesso!"
    else
        echo "⏭️ Instalação do Dockly ignorada."
    fi
else
    echo "✅ Dockly já está instalado."
fi
