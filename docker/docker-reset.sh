#!/bin/bash
# Script com duas opções:
# 1) Limpeza de recursos não utilizados (preserva recursos usados por containers UP)
# 2) Reset total do Docker

show_status() {
    echo ""
    echo "📊 Status atual:"
    echo "Containers: $(docker ps -a --format 'table {{.Names}}' | wc -l | awk '{print $1-1}')"
    echo "Imagens: $(docker images --format 'table {{.Repository}}' | wc -l | awk '{print $1-1}')"
    echo "Volumes: $(docker volume ls --format 'table {{.Name}}' | wc -l | awk '{print $1-1}')"
    echo "Redes: $(docker network ls --format 'table {{.Name}}' | grep -v -E '^(bridge|host|none)$' | wc -l)"
}

run_soft_cleanup() {
    echo ""
    echo "🧹 Iniciando limpeza de recursos não utilizados..."
    echo "ℹ️  Recursos em uso por containers UP serão preservados"

    # Remover apenas containers parados
    echo "🗑️  Removendo containers parados..."
    STOPPED_CONTAINERS=$(docker ps -aq -f status=exited -f status=created -f status=dead)
    if [ -n "$STOPPED_CONTAINERS" ]; then
        echo "$STOPPED_CONTAINERS" | xargs -r docker rm --force
    else
        echo "   ℹ️  Nenhum container parado para remover."
    fi

    # Limpar cache do Buildx
    echo "🔨 Limpando cache do Buildx não utilizado..."
    docker buildx prune --all --force 2>/dev/null || {
        echo "   ℹ️  Buildx não disponível ou sem cache para limpar"
    }

    # Remover imagens, volumes, redes e cache não utilizados
    echo "🧽 Limpando imagens, volumes e redes não utilizados..."
    docker system prune --all --volumes --force 2>/dev/null || {
        echo "   ⚠️  Erro ao executar system prune, continuando..."
    }

    echo ""
    echo "✅ Limpeza concluída com sucesso!"
    echo "🐳 Containers em execução e seus recursos permanecem ativos"
}

run_full_reset() {
    echo ""
    echo "🔄 Iniciando reset completo do Docker..."

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
    echo "🎉 Docker foi completamente resetado!"
    echo "💡 Agora você pode começar com uma instalação limpa"
    echo "🔄 O Docker está no mesmo estado de quando foi instalado pela primeira vez"
}

echo "🐳 Gerenciamento de limpeza/reset do Docker"
echo "==========================================="
echo ""
echo "Escolha uma opção:"
echo "  1) Limpar recursos não utilizados (preserva recursos usados por containers UP) [padrão]"
echo "  2) Reset total (apaga tudo e reinicia Docker)"
echo ""

# Verificar se o Docker está instalado
if ! command -v docker &> /dev/null; then
    echo "❌ Docker não está instalado!"
    exit 1
fi

echo -n "📝 Opção [1/2] (Enter = 1): "
read -r opcao
opcao=${opcao:-1}

case "$opcao" in
    1)
        echo ""
        echo "✅ Opção selecionada: limpeza de recursos não utilizados"
        run_soft_cleanup
        ;;
    2)
        echo ""
        echo "🚨 AVISO: RESET TOTAL DO DOCKER 🚨"
        echo "⚠️  Esta opção irá apagar TODOS os dados do Docker."
        while true; do
            echo -n "📝 Para confirmar o reset total, digite 'confirmo' (ou 'cancelar' para sair): "
            read -r confirmacao

            if [ "$confirmacao" = "confirmo" ]; then
                run_full_reset
                break
            elif [ "$confirmacao" = "cancelar" ] || [ "$confirmacao" = "sair" ]; then
                echo ""
                echo "❌ Operação cancelada pelo usuário."
                echo "🐳 Docker permanece inalterado."
                exit 0
            else
                echo ""
                echo "❌ Confirmação inválida."
                echo ""
            fi
        done
        ;;
    *)
        echo ""
        echo "❌ Opção inválida: $opcao"
        echo "💡 Use 1 ou 2"
        exit 1
        ;;
esac

show_status