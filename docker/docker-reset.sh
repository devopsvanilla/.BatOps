#!/usr/bin/env bash
# TODO: Revisar e adicionar set -euo pipefail — Issue #1
# Script com duas opções:
# 1) Limpeza de recursos não utilizados (preserva recursos usados por containers UP)
# 2) Reset total do Docker

NUCLEAR_MODE=false
ASSUME_YES=false
OPTION_CHOICE=""
DRY_RUN=false

print_help() {
    echo "Uso: $0 [opções]"
    echo ""
    echo "Opções:"
    echo "  -h, --help         Mostra esta ajuda e sai"
    echo "  --nuclear          Mostra prévia dos serviços systemd com docker compose e pede confirmação extra"
    echo "  --yes, -y          Confirma automaticamente prompts destrutivos (uso avançado)"
    echo "  --option, -o N     Define a opção sem prompt (1 ou 2)"
    echo "  --dry-run          Simula as ações sem remover nada"
    echo ""
    echo "Exemplos:"
    echo "  $0"
    echo "  $0 --option 1"
    echo "  $0 --option 2"
    echo "  $0 --option 2 --yes"
    echo "  $0 --option 2 --nuclear"
    echo "  $0 --option 2 --nuclear --yes"
    echo "  $0 --option 2 --nuclear --dry-run"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            print_help
            exit 0
            ;;
        --nuclear)
            NUCLEAR_MODE=true
            shift
            ;;
        --yes|-y)
            ASSUME_YES=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --option|-o)
            if [[ -n "$2" ]]; then
                OPTION_CHOICE="$2"
                shift 2
            else
                echo "❌ Erro: '$1' requer um valor (1 ou 2)."
                exit 1
            fi
            ;;
        --option=*|-o=*)
            OPTION_CHOICE="${1#*=}"
            shift
            ;;
        *)
            echo "❌ Argumento inválido: $1"
            echo ""
            print_help
            exit 1
            ;;
    esac
done

show_status() {
    echo ""
    echo "📊 Status atual:"
    echo "Containers: $(docker ps -a --format 'table {{.Names}}' | wc -l | awk '{print $1-1}')"
    echo "Imagens: $(docker images --format 'table {{.Repository}}' | wc -l | awk '{print $1-1}')"
    echo "Volumes: $(docker volume ls --format 'table {{.Name}}' | wc -l | awk '{print $1-1}')"
    echo "Redes: $(docker network ls --format 'table {{.Name}}' | grep -v -E '^(bridge|host|none)$' | wc -l)"
}

get_compose_systemd_units() {
    sudo systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | while read -r unit; do
        execstart=$(sudo systemctl show -p ExecStart --value "$unit" 2>/dev/null || true)
        if echo "$execstart" | grep -Eiq 'docker[[:space:]]+compose|docker-compose'; then
            echo "$unit"
        fi
    done
}

preview_soft_cleanup() {
    echo ""
    echo "🧪 DRY-RUN: simulação da limpeza de recursos não utilizados (opção 1)"

    STOPPED_CONTAINERS=$(docker ps -aq -f status=exited -f status=created -f status=dead 2>/dev/null || true)
    STOPPED_COUNT=$(echo "$STOPPED_CONTAINERS" | sed '/^$/d' | wc -l)
    echo "   • Containers parados que seriam removidos: $STOPPED_COUNT"

    echo "   • Cache Buildx: seria limpo (buildx prune --all --force)"
    echo "   • system prune --all --volumes: seria executado (somente recursos sem uso)"
    echo ""
    echo "✅ Dry-run concluído. Nenhuma alteração foi aplicada."
}

preview_full_reset() {
    echo ""
    echo "🧪 DRY-RUN: simulação do reset total (opção 2)"

    ALL_CONTAINERS=$(docker ps -aq 2>/dev/null || true)
    RUNNING_CONTAINERS=$(docker ps -q 2>/dev/null || true)
    ALL_IMAGES=$(docker images -q 2>/dev/null | sort -u || true)
    VOLUMES=$(docker volume ls -q 2>/dev/null || true)
    CUSTOM_NETWORKS=$(docker network ls --format "{{.Name}}" 2>/dev/null | grep -v -E "^(bridge|host|none)$" || true)

    CONTAINERS_COUNT=$(echo "$ALL_CONTAINERS" | sed '/^$/d' | wc -l)
    RUNNING_COUNT=$(echo "$RUNNING_CONTAINERS" | sed '/^$/d' | wc -l)
    IMAGES_COUNT=$(echo "$ALL_IMAGES" | sed '/^$/d' | wc -l)
    VOLUMES_COUNT=$(echo "$VOLUMES" | sed '/^$/d' | wc -l)
    NETWORKS_COUNT=$(echo "$CUSTOM_NETWORKS" | sed '/^$/d' | wc -l)

    mapfile -t PREVIEW_UNITS < <(get_compose_systemd_units)

    echo "   • Containers em execução que seriam parados: $RUNNING_COUNT"
    echo "   • Containers totais que seriam removidos: $CONTAINERS_COUNT"
    echo "   • Imagens que seriam removidas: $IMAGES_COUNT"
    echo "   • Volumes que seriam removidos: $VOLUMES_COUNT"
    echo "   • Redes customizadas que seriam removidas: $NETWORKS_COUNT"
    echo "   • Buildx prune e system prune: seriam executados"
    echo "   • Serviços docker/containerd: seriam parados e reiniciados"
    echo "   • Diretórios /var/lib/docker e /var/lib/containerd: seriam removidos e recriados"

    if [ "${#PREVIEW_UNITS[@]}" -gt 0 ]; then
        echo "   • Serviços systemd com docker compose que seriam desabilitados:"
        for unit in "${PREVIEW_UNITS[@]}"; do
            echo "     - $unit"
        done
    else
        echo "   • Serviços systemd com docker compose: nenhum detectado"
    fi

    echo ""
    echo "✅ Dry-run concluído. Nenhuma alteração foi aplicada."
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

    # Desabilitar políticas de restart para evitar containers "zumbis"
    echo "🧷 Desabilitando políticas de restart de todos os containers..."
    ALL_CONTAINERS_FOR_RESTART=$(docker ps -aq 2>/dev/null || true)
    if [ -n "$ALL_CONTAINERS_FOR_RESTART" ]; then
        echo "$ALL_CONTAINERS_FOR_RESTART" | xargs -r docker update --restart=no >/dev/null 2>&1 || true
    fi

    # Desativar unidades systemd que iniciam docker compose automaticamente
    echo "🛑 Verificando serviços systemd com docker compose (auto-start)..."
    mapfile -t COMPOSE_SYSTEMD_UNITS < <(get_compose_systemd_units)

    if [ "${#COMPOSE_SYSTEMD_UNITS[@]}" -gt 0 ]; then
        printf '   ℹ️  Serviços detectados: %s\n' "${COMPOSE_SYSTEMD_UNITS[*]}"
        for unit in "${COMPOSE_SYSTEMD_UNITS[@]}"; do
            sudo systemctl disable --now "$unit" >/dev/null 2>&1 || true
        done
    else
        echo "   ℹ️  Nenhum serviço systemd com docker compose foi detectado."
    fi

    # Limpar stacks e serviços Swarm para impedir recriação automática
    echo "🧹 Removendo stacks/serviços do Swarm (se houver)..."
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        SWARM_STACKS=$(docker stack ls --format '{{.Name}}' 2>/dev/null || true)
        if [ -n "$SWARM_STACKS" ]; then
            echo "$SWARM_STACKS" | xargs -r -n1 docker stack rm >/dev/null 2>&1 || true
        fi

        SWARM_SERVICES=$(docker service ls -q 2>/dev/null || true)
        if [ -n "$SWARM_SERVICES" ]; then
            echo "$SWARM_SERVICES" | xargs -r docker service rm >/dev/null 2>&1 || true
        fi
    fi

    # Parar todos os containers em execução
    echo "🛑 Parando todos os containers..."
    for _ in 1 2 3 4 5; do
        RUNNING_CONTAINERS=$(docker ps -q 2>/dev/null || true)
        if [ -n "$RUNNING_CONTAINERS" ]; then
            echo "$RUNNING_CONTAINERS" | xargs -r docker stop >/dev/null 2>&1 || true
        else
            break
        fi
        sleep 1
    done

    # Remover todos os containers (incluindo os parados), com repetição para evitar recriação em corrida
    echo "🗑️  Removendo todos os containers..."
    for _ in 1 2 3 4 5; do
        ALL_CONTAINERS=$(docker ps -aq 2>/dev/null || true)
        if [ -n "$ALL_CONTAINERS" ]; then
            echo "$ALL_CONTAINERS" | xargs -r docker rm --force >/dev/null 2>&1 || true
        else
            break
        fi
        sleep 1
    done

    REMAINING_CONTAINERS=$(docker ps -aq 2>/dev/null || true)
    if [ -n "$REMAINING_CONTAINERS" ]; then
        echo "   ⚠️  Alguns containers ainda existem. Forçando remoção com daemon ativo..."
        echo "$REMAINING_CONTAINERS" | xargs -r docker rm --force >/dev/null 2>&1 || true
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

    # Parar serviços do Docker e container runtime
    echo "⏸️  Parando serviços Docker/containerd..."
    sudo systemctl stop docker.service docker.socket containerd.service >/dev/null 2>&1 || true

    # Remover dados persistentes do Docker
    echo "🗂️  Removendo dados persistentes..."
    sudo rm -rf /var/lib/docker /var/lib/containerd
    sudo mkdir -p /var/lib/docker /var/lib/containerd

    # Limpar logs do Docker
    echo "📋 Limpando logs..."
    sudo rm -rf /var/log/docker.log
    sudo rm -f /var/run/docker.sock /var/run/docker.pid
    sudo journalctl --vacuum-time=1s >/dev/null 2>&1 || true

    # Reiniciar o serviço Docker
    echo "🔄 Reiniciando serviço Docker..."
    sudo systemctl start containerd.service >/dev/null 2>&1 || true
    sudo systemctl start docker.service
    sudo systemctl enable docker.service >/dev/null 2>&1 || true

    # Passada final após restart para garantir que nada ressuscitou
    echo "🔍 Verificação final de containers remanescentes..."
    FINAL_CONTAINERS=$(docker ps -aq 2>/dev/null || true)
    if [ -n "$FINAL_CONTAINERS" ]; then
        echo "$FINAL_CONTAINERS" | xargs -r docker update --restart=no >/dev/null 2>&1 || true
        echo "$FINAL_CONTAINERS" | xargs -r docker rm --force >/dev/null 2>&1 || true
    fi

    # Verificar se o Docker está funcionando
    echo "✅ Verificando instalação..."
    if docker --version && docker info > /dev/null 2>&1; then
        if [ -n "$(docker ps -aq 2>/dev/null || true)" ]; then
            echo "⚠️  Ainda existem containers após o reset."
            echo "   Revise serviços externos que re-criam containers (cron/systemd/orquestrador externo)."
        fi
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
echo "Modo opcional:"
echo "  --nuclear  Exibe prévia dos serviços systemd com docker compose e exige confirmação extra"
echo "  --yes|-y   Confirma automaticamente prompts destrutivos (uso avançado)"
echo "  --option|-o  Define a opção sem prompt (1 ou 2)"
echo "  --dry-run  Simula as ações sem remover nada"
echo ""

# Verificar se o Docker está instalado
if ! command -v docker &> /dev/null; then
    echo "❌ Docker não está instalado!"
    exit 1
fi

if [ -n "$OPTION_CHOICE" ]; then
    opcao="$OPTION_CHOICE"
    echo "🧾 Opção recebida via argumento: $opcao"
else
    echo -n "📝 Opção [1/2] (Enter = 1): "
    read -r opcao
    opcao=${opcao:-1}
fi

if [[ "$opcao" != "1" && "$opcao" != "2" ]]; then
    echo ""
    echo "❌ Opção inválida: $opcao"
    echo "💡 Use 1 ou 2"
    exit 1
fi

case "$opcao" in
    1)
        echo ""
        echo "✅ Opção selecionada: limpeza de recursos não utilizados"
        if [ "$DRY_RUN" = true ]; then
            preview_soft_cleanup
        else
            run_soft_cleanup
        fi
        ;;
    2)
        echo ""
        echo "🚨 AVISO: RESET TOTAL DO DOCKER 🚨"
        echo "⚠️  Esta opção irá apagar TODOS os dados do Docker."

        if [ "$DRY_RUN" = true ]; then
            echo "🧪 Modo dry-run ativo: nenhuma alteração destrutiva será aplicada."
            preview_full_reset
        else
            if [ "$NUCLEAR_MODE" = true ]; then
                echo ""
                echo "☢️  MODO NUCLEAR ATIVADO"
                echo "🔎 Prévia dos serviços systemd que serão desabilitados (docker compose):"
                mapfile -t PREVIEW_UNITS < <(get_compose_systemd_units)
                if [ "${#PREVIEW_UNITS[@]}" -gt 0 ]; then
                    for unit in "${PREVIEW_UNITS[@]}"; do
                        echo "   - $unit"
                    done
                else
                    echo "   ℹ️  Nenhum serviço systemd com docker compose detectado."
                fi

                if [ "$ASSUME_YES" = true ]; then
                    echo "🤖 --yes ativo: confirmação extra do modo nuclear aplicada automaticamente."
                else
                    echo -n "📝 Confirmação extra: digite 'nuclear' para continuar (ou Enter para cancelar): "
                    read -r nuclear_confirm
                    if [ "$nuclear_confirm" != "nuclear" ]; then
                        echo ""
                        echo "❌ Operação cancelada: confirmação do modo nuclear não informada."
                        exit 0
                    fi
                fi
            fi

            if [ "$ASSUME_YES" = true ]; then
                echo "🤖 --yes ativo: confirmação 'confirmo' aplicada automaticamente."
                run_full_reset
            else
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
            fi
        fi
        ;;
    *)
        echo ""
        echo "❌ Opção inválida: $opcao"
        echo "💡 Use 1 ou 2"
        exit 1
        ;;
esac

show_status