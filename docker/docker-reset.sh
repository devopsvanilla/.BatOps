#!/bin/bash
# Script para reset completo do Docker
# Remove todos os containers, imagens, volumes, redes e dados
# Mantém apenas o Docker instalado

echo "🚨 AVISO: RESET TOTAL DO DOCKER 🚨"
echo "======================================"
echo ""
echo "⚠️  Este script irá:"
echo "   • Parar todos os containers em execução"
echo "   • Remover TODOS os containers (ativos e parados)"
echo "   • Remover TODAS as imagens Docker"
echo "   • Remover TODOS os volumes persistentes"
echo "   • Remover todas as redes customizadas"
echo "   • Limpar todos os caches e dados do Docker"
echo "   • Reiniciar o Docker para o estado inicial da instalação"
echo ""
echo "❌ TODOS OS DADOS SERÃO PERDIDOS PERMANENTEMENTE!"
echo "💾 Faça backup de dados importantes antes de continuar"
echo ""
echo "🔄 O Docker será reiniciado e voltará ao estado inicial da instalação"
echo ""

# Solicitar confirmação do usuário
while true; do
    echo -n "📝 Para confirmar este reset total, digite 'confirmo': "
    read -r confirmacao
    
    if [ "$confirmacao" = "confirmo" ]; then
        echo ""
        echo "✅ Confirmação recebida. Iniciando reset total do Docker..."
        break
    elif [ "$confirmacao" = "cancelar" ] || [ "$confirmacao" = "sair" ]; then
        echo ""
        echo "❌ Operação cancelada pelo usuário."
        echo "🐳 Docker permanece inalterado."
        exit 0
    else
        echo ""
        echo "❌ Confirmação inválida. Digite 'confirmo' para prosseguir ou 'cancelar' para sair."
        echo ""
    fi
done

echo ""
echo "🔄 Iniciando reset completo do Docker..."

# Verificar se o Docker está instalado
if ! command -v docker &> /dev/null; then
    echo "❌ Docker não está instalado!"
    exit 1
fi

# Parar todos os containers em execução
echo "🛑 Parando todos os containers..."
RUNNING_CONTAINERS=$(docker ps -q)
if [ -n "$RUNNING_CONTAINERS" ]; then
    echo "$RUNNING_CONTAINERS" | xargs -r docker stop
else
    echo "   ℹ️  Nenhum container em execução para parar."
fi

# Remover todos os containers (incluindo os parados)
echo "🗑️  Removendo todos os containers..."
ALL_CONTAINERS=$(docker ps -aq)
if [ -n "$ALL_CONTAINERS" ]; then
    echo "$ALL_CONTAINERS" | xargs -r docker rm --force
else
    echo "   ℹ️  Nenhum container para remover."
fi

# Remover todas as imagens
echo "🖼️  Removendo todas as imagens..."
ALL_IMAGES=$(docker images -q)
if [ -n "$ALL_IMAGES" ]; then
    echo "$ALL_IMAGES" | xargs -r docker rmi --force
else
    echo "   ℹ️  Nenhuma imagem para remover."
fi

# Remover todos os volumes
echo "💾 Removendo todos os volumes..."
VOLUMES=$(docker volume ls -q 2>/dev/null || true)
if [ -n "$VOLUMES" ]; then
    echo "$VOLUMES" | xargs -r docker volume rm --force 2>/dev/null || true
else
    echo "   ℹ️  Nenhum volume encontrado para remover"
fi

# Remover todas as redes customizadas
echo "🌐 Removendo redes customizadas..."
CUSTOM_NETWORKS=$(docker network ls --format "{{.Name}}" 2>/dev/null | grep -v -E "^(bridge|host|none)$" || true)
if [ -n "$CUSTOM_NETWORKS" ]; then
    echo "$CUSTOM_NETWORKS" | xargs -r docker network rm 2>/dev/null || true
else
    echo "   ℹ️  Nenhuma rede customizada encontrada para remover"
fi

# Remover dados do Docker Buildx
echo "🔨 Limpando cache do Buildx..."
docker buildx prune --all --force 2>/dev/null || {
    echo "   ℹ️  Buildx não disponível ou sem cache para limpar"
}

# Remover cache do sistema Docker
echo "🧹 Limpando cache do sistema..."
docker system prune --all --volumes --force 2>/dev/null || {
    echo "   ⚠️  Erro ao executar system prune, continuando..."
}

# Parar o serviço Docker
echo "⏸️  Parando serviço Docker..."
sudo systemctl stop docker

# Remover dados persistentes do Docker
echo "🗂️  Removendo dados persistentes..."
sudo rm -rf /var/lib/docker/*
sudo rm -rf /var/lib/containerd/*

# Limpar logs do Docker
echo "📋 Limpando logs..."
sudo rm -rf /var/log/docker.log
sudo journalctl --vacuum-time=1s

# Reiniciar o serviço Docker
echo "🔄 Reiniciando serviço Docker..."
sudo systemctl start docker
sudo systemctl enable docker

# Verificar se o Docker está funcionando
echo "✅ Verificando instalação..."
if docker --version && docker info > /dev/null 2>&1; then
    echo "✅ Reset completo realizado com sucesso!"
    echo "🐳 Docker resetado e funcionando normalmente"
    docker --version
else
    echo "❌ Erro: Docker não está funcionando corretamente após o reset"
    exit 1
fi

echo ""
echo "📊 Status atual:"
echo "Containers: $(docker ps -a --format 'table {{.Names}}' | wc -l | awk '{print $1-1}')"
echo "Imagens: $(docker images --format 'table {{.Repository}}' | wc -l | awk '{print $1-1}')"
echo "Volumes: $(docker volume ls --format 'table {{.Name}}' | wc -l | awk '{print $1-1}')"
echo "Redes: $(docker network ls --format 'table {{.Name}}' | grep -v -E '^(bridge|host|none)$' | wc -l)"

echo ""
echo "🎉 Docker foi completamente resetado!"
echo "💡 Agora você pode começar com uma instalação limpa"
echo "🔄 O Docker está no mesmo estado de quando foi instalado pela primeira vez"