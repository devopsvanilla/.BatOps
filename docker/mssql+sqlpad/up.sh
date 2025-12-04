#!/bin/bash

# Script para iniciar MSSQL + SQLPad com seleção de rede Docker
# Suporta contextos locais e remotos (SSH) com resolução de DNS

clear

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variáveis globais
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_PATH=""
IS_REMOTE=false
CURRENT_CONTEXT=""
SELECTED_CONTEXT=""
SELECTED_NETWORK=""
declare -a LOCAL_COMPOSE_CMD=()
declare -a REMOTE_COMPOSE_CMD=()
LOCAL_COMPOSE_DISPLAY=""
REMOTE_COMPOSE_DISPLAY=""
UTILITY_IMAGE="busybox:1.36.1"

# Função para exibir mensagens
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Função para verificar se o arquivo .env existe
check_env_file() {
    if [ ! -f .env ]; then
        error "Arquivo .env não encontrado!"
        warning "Copie o arquivo .env-sample para .env e configure as variáveis:"
        echo "  cp .env-sample .env"
        exit 1
    fi
}

# Função para obter o contexto Docker atual
get_docker_context() {
    if [ -n "$SELECTED_CONTEXT" ]; then
        echo "$SELECTED_CONTEXT"
    else
        docker context show 2>/dev/null || echo "default"
    fi
}

# Função para listar e selecionar contexto Docker
select_docker_context() {
    local current_context="$1"
    local contexts=()
    local context_names=()

    info "Listando contextos Docker disponíveis..."
    mapfile -t contexts < <(docker context ls --format '{{.Name}}|{{if .Current}}true{{else}}false{{end}}|{{.DockerEndpoint}}')

    if [ ${#contexts[@]} -eq 0 ]; then
        error "Nenhum contexto Docker foi encontrado."
        exit 1
    fi

    echo ""
    echo "Contextos detectados:"
    for i in "${!contexts[@]}"; do
        IFS='|' read -r name is_current endpoint <<< "${contexts[$i]}"
        context_names[$i]="$name"
        local label=""
        if [ "$is_current" = "true" ]; then
            label="(atual)"
        fi
        printf "  %2d. %s %s\n" "$((i+1))" "$name" "$label"
        if [ -n "$endpoint" ]; then
            printf "       Endpoint: %s\n" "$endpoint"
        fi
    done
    echo ""

    local choice
    while true; do
        read -p "Selecione um contexto [1-${#contexts[@]}] ou pressione ENTER para manter '${current_context}': " choice

        if [ -z "$choice" ]; then
            SELECTED_CONTEXT="$current_context"
            return 0
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#contexts[@]} ]; then
            local selected_index=$((choice-1))
            SELECTED_CONTEXT="${context_names[$selected_index]}"
            return 0
        fi

        error "Opção inválida. Informe um número entre 1 e ${#contexts[@]} ou pressione ENTER."
    done
}

# Função para obter informações do contexto remoto
get_remote_context_info() {
    local context_name="${1:-$(get_docker_context)}"
    local endpoint=$(docker context inspect "$context_name" --format '{{.Endpoints.docker.Host}}' 2>/dev/null || echo "")
    
    if [[ "$endpoint" == "ssh://"* ]]; then
        # Extrair usuário e host do endpoint SSH
        # Formato: ssh://user@host ou ssh://host
        local ssh_part="${endpoint#ssh://}"
        
        if [[ "$ssh_part" == *"@"* ]]; then
            REMOTE_USER="${ssh_part%%@*}"
            REMOTE_HOST="${ssh_part#*@}"
        else
            REMOTE_USER="$(whoami)"
            REMOTE_HOST="$ssh_part"
        fi
        
        # Remover porta se existir
        REMOTE_HOST="${REMOTE_HOST%%:*}"
        
        return 0
    fi
    
    return 1
}

# Função para verificar se é contexto remoto
is_remote_context() {
    local context_name="${1:-$(get_docker_context)}"
    local endpoint=$(docker context inspect "$context_name" --format '{{.Endpoints.docker.Host}}' 2>/dev/null || echo "")
    
    if [[ "$endpoint" == "unix://"* ]] || [[ -z "$endpoint" ]]; then
        return 1  # Local
    else
        return 0  # Remoto
    fi
}

# Funções auxiliares para Docker Compose
ensure_local_compose_cmd() {
    if [ ${#LOCAL_COMPOSE_CMD[@]} -gt 0 ]; then
        return 0
    fi

    if docker compose version >/dev/null 2>&1; then
        LOCAL_COMPOSE_CMD=("docker" "compose")
        LOCAL_COMPOSE_DISPLAY="docker compose"
        return 0
    fi

    if command -v docker-compose >/dev/null 2>&1; then
        warning "Docker Compose v1 detectado. Considere migrar para 'docker compose'."
        LOCAL_COMPOSE_CMD=("docker-compose")
        LOCAL_COMPOSE_DISPLAY="docker-compose"
        return 0
    fi

    return 1
}

ensure_remote_compose_cmd() {
    if [ ${#REMOTE_COMPOSE_CMD[@]} -gt 0 ]; then
        return 0
    fi

    if remote_exec "docker compose version >/dev/null 2>&1"; then
        REMOTE_COMPOSE_CMD=("docker" "compose")
        REMOTE_COMPOSE_DISPLAY="docker compose"
        return 0
    fi

    if remote_exec "command -v docker-compose >/dev/null 2>&1"; then
        warning "Docker Compose v1 detectado no host remoto. Considere migrar para 'docker compose'."
        REMOTE_COMPOSE_CMD=("docker-compose")
        REMOTE_COMPOSE_DISPLAY="docker-compose"
        return 0
    fi

    return 1
}

run_local_compose() {
    if ! ensure_local_compose_cmd; then
        error "Docker Compose não está disponível localmente. Instale docker compose v2 ou docker-compose."
        exit 1
    fi

    "${LOCAL_COMPOSE_CMD[@]}" "$@"
}

run_remote_compose() {
    if ! ensure_remote_compose_cmd; then
        error "Docker Compose não está disponível no host remoto."
        exit 1
    fi

    local compose_cmd="${REMOTE_COMPOSE_CMD[*]}"
    local compose_args="$*"

    if [ -n "$REMOTE_PATH" ]; then
        remote_exec "cd ${REMOTE_PATH} && ${compose_cmd} ${compose_args}"
    else
        remote_exec "${compose_cmd} ${compose_args}"
    fi
}

ensure_image_available() {
    local image="$1"
    if ! docker image inspect "$image" >/dev/null 2>&1; then
        info "Baixando imagem utilitária '$image'..."
        docker pull "$image" >/dev/null
    fi
}

ensure_volume_exists() {
    local volume_name="$1"
    if ! docker volume inspect "$volume_name" >/dev/null 2>&1; then
        info "Criando volume Docker '${volume_name}'..."
        docker volume create "$volume_name" >/dev/null
    fi
}

prepare_volume_permissions() {
    local volume_name="$1"
    local uid_gid="$2"
    ensure_image_available "$UTILITY_IMAGE"
    ensure_volume_exists "$volume_name"

    info "Ajustando permissões do volume '${volume_name}' para ${uid_gid}..."
    docker run --rm -v "${volume_name}:/mnt/volume" "$UTILITY_IMAGE" \
        sh -c "mkdir -p /mnt/volume && chown -R ${uid_gid} /mnt/volume"
}

prepare_persistent_volumes() {
    local mssql_data_vol mssql_log_vol mssql_secrets_vol sqlpad_data_vol

    mssql_data_vol="$(get_env_var "MSSQL_DATA_VOLUME")"
    mssql_log_vol="$(get_env_var "MSSQL_LOG_VOLUME")"
    mssql_secrets_vol="$(get_env_var "MSSQL_SECRETS_VOLUME")"
    sqlpad_data_vol="$(get_env_var "SQLPAD_DATA_VOLUME")"

    mssql_data_vol="${mssql_data_vol:-mssql-data}"
    mssql_log_vol="${mssql_log_vol:-mssql-log}"
    mssql_secrets_vol="${mssql_secrets_vol:-mssql-secrets}"
    sqlpad_data_vol="${sqlpad_data_vol:-sqlpad-data}"

    # MSSQL volumes precisam pertencer ao usuário 10001:0
    prepare_volume_permissions "$mssql_data_vol" "10001:0"
    prepare_volume_permissions "$mssql_log_vol" "10001:0"
    prepare_volume_permissions "$mssql_secrets_vol" "10001:0"

    # SQLPad roda como root na imagem oficial, mas garantimos existência do volume
    ensure_volume_exists "$sqlpad_data_vol"
}

# Função para executar comando no host remoto via SSH
remote_exec() {
    local cmd="$1"
    if [ "$IS_REMOTE" = true ] && [ -n "$REMOTE_HOST" ]; then
        ssh "${REMOTE_USER}@${REMOTE_HOST}" "$cmd"
    else
        eval "$cmd"
    fi
}

# Função para copiar arquivo para o host remoto
copy_to_remote() {
    local local_file="$1"
    local remote_file="$2"
    
    if [ "$IS_REMOTE" = true ] && [ -n "$REMOTE_HOST" ]; then
        info "Copiando $local_file para ${REMOTE_USER}@${REMOTE_HOST}:${remote_file}"
        scp "$local_file" "${REMOTE_USER}@${REMOTE_HOST}:${remote_file}"
    fi
}

# Função para copiar arquivo do host remoto
copy_from_remote() {
    local remote_file="$1"
    local local_file="$2"
    
    if [ "$IS_REMOTE" = true ] && [ -n "$REMOTE_HOST" ]; then
        info "Copiando ${REMOTE_USER}@${REMOTE_HOST}:${remote_file} para $local_file"
        scp "${REMOTE_USER}@${REMOTE_HOST}:${remote_file}" "$local_file"
    fi
}

# Função para detectar o diretório remoto do projeto
detect_remote_path() {
    if [ "$IS_REMOTE" = true ] && [ -n "$REMOTE_HOST" ]; then
        # Verificar se o docker-compose.yml existe em algum caminho padrão
        local current_dir="$(basename "$PWD")"
        local parent_dir="$(basename "$(dirname "$PWD")")"
        
        # Tentar encontrar o arquivo docker-compose.yml no host remoto
        info "Procurando docker-compose.yml no host remoto..."
        
        # Verificar se existe em ~/docker/mssql+sqlpad/
        if remote_exec "[ -f ~/docker/mssql+sqlpad/docker-compose.yml ]" 2>/dev/null; then
            REMOTE_PATH="~/docker/mssql+sqlpad"
            return 0
        fi
        
        # Verificar se existe em ~/.BatOps/docker/mssql+sqlpad/
        if remote_exec "[ -f ~/.BatOps/docker/mssql+sqlpad/docker-compose.yml ]" 2>/dev/null; then
            REMOTE_PATH="~/.BatOps/docker/mssql+sqlpad"
            return 0
        fi
        
        # Se não encontrou, perguntar ao usuário
        echo ""
        read -p "Digite o caminho completo do projeto no host remoto: " user_path
        REMOTE_PATH="$user_path"
    fi
}

# Função para listar redes Docker disponíveis
list_docker_networks() {
    local ctx=$(get_docker_context)
    info "Listando redes Docker disponíveis no contexto '${ctx}'..."
    docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
}

# Função para criar nova rede se necessário
create_network_if_needed() {
    local network_name=$1
    
    if ! docker network inspect "$network_name" &>/dev/null; then
        info "Rede '$network_name' não existe. Criando..."
        docker network create "$network_name" --driver bridge
        success "Rede '$network_name' criada com sucesso!"
    else
        info "Rede '$network_name' já existe."
    fi
}

# Função para atualizar variável no arquivo .env
update_env_var() {
    local var_name="$1"
    local var_value="$2"
    local env_file="${3:-.env}"
    
    if grep -q "^${var_name}=" "$env_file"; then
        # Atualizar variável existente
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s/^${var_name}=.*/${var_name}=${var_value}/" "$env_file"
        else
            # Linux
            sed -i "s/^${var_name}=.*/${var_name}=${var_value}/" "$env_file"
        fi
    else
        # Adicionar variável
        echo "${var_name}=${var_value}" >> "$env_file"
    fi
}

# Função para obter valor de uma variável no .env
get_env_var() {
    local var_name="$1"
    local env_file="${2:-.env}"

    if [ -f "$env_file" ]; then
        local value
        value=$(grep -E "^${var_name}=" "$env_file" | tail -n 1 | cut -d '=' -f2-)
        value="${value%$'\r'}"  # Remover carriage return se houver
        # Remover aspas simples ou duplas ao redor, se existirem
        value="${value%\"}"; value="${value#\"}"
        value="${value%\'}"; value="${value#\'}"
        echo "$value"
    fi
}

# Função para sincronizar .env com o host remoto
sync_env_to_remote() {
    if [ "$IS_REMOTE" = true ] && [ -n "$REMOTE_HOST" ] && [ -n "$REMOTE_PATH" ]; then
        info "Sincronizando arquivo .env com host remoto..."
        copy_to_remote ".env" "${REMOTE_PATH}/.env"
        success "Arquivo .env sincronizado!"
    fi
}

# Função para sincronizar arquivos do projeto com o host remoto
sync_project_to_remote() {
    if [ "$IS_REMOTE" = true ] && [ -n "$REMOTE_HOST" ] && [ -n "$REMOTE_PATH" ]; then
        info "Sincronizando arquivos do projeto com host remoto..."
        
        # Criar diretório remoto se não existir
        remote_exec "mkdir -p ${REMOTE_PATH}"
        
        # Sincronizar arquivos necessários
        copy_to_remote "docker-compose.yml" "${REMOTE_PATH}/docker-compose.yml"
        copy_to_remote ".env" "${REMOTE_PATH}/.env"
        
        # Copiar sample se existir
        if [ -f ".env-sample" ]; then
            copy_to_remote ".env-sample" "${REMOTE_PATH}/.env-sample"
        fi
        
        success "Projeto sincronizado com host remoto!"
    fi
}

# Função para selecionar rede
select_network() {
    echo ""
    echo "======================================"
    echo "  Seleção de Rede Docker"
    echo "======================================"
    echo ""
    
    local current_env_network
    current_env_network=$(get_env_var "MSSQL_NETWORK")

    if [ -n "$current_env_network" ]; then
        echo "Rede configurada atualmente no .env: $current_env_network"
        read -p "Deseja reutilizar esta rede? (S/n): " reuse_choice
        reuse_choice=${reuse_choice:-S}
        if [[ "$reuse_choice" =~ ^[sS]$ ]]; then
            info "Mantendo rede $current_env_network configurada no .env"
                SELECTED_NETWORK="$current_env_network"
            return 0
        fi
        echo ""
    fi

    list_docker_networks
    echo ""
    
    # Obter lista de redes disponíveis (ignorando padrões bridge/host/none)
    mapfile -t networks < <(docker network ls --format "{{.Name}}" | grep -Ev '^(bridge|host|none)$' || true)

    if [ ${#networks[@]} -eq 0 ]; then
        warning "Nenhuma rede personalizada encontrada neste contexto."
        while true; do
            read -p "Informe o nome da nova rede que será criada: " new_network
            if [ -n "$new_network" ]; then
                create_network_if_needed "$new_network"
                    SELECTED_NETWORK="$new_network"
                return 0
            fi
            error "Nome da rede não pode ser vazio!"
        done
    fi
    
    echo "Redes disponíveis:"
    for i in "${!networks[@]}"; do
        echo "  $((i+1)). ${networks[$i]}"
    done
    echo "  $((${#networks[@]}+1)). Criar nova rede"
    echo "  $((${#networks[@]}+2)). Usar padrão (mssql-network)"
    echo ""
    
    while true; do
        read -p "Selecione uma opção [1-$((${#networks[@]}+2))]: " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $((${#networks[@]}+2)) ]; then
            if [ "$choice" -eq $((${#networks[@]}+1)) ]; then
                # Criar nova rede
                read -p "Nome da nova rede: " new_network
                if [ -n "$new_network" ]; then
                    create_network_if_needed "$new_network"
                        SELECTED_NETWORK="$new_network"
                    return 0
                else
                    error "Nome da rede não pode ser vazio!"
                    continue
                fi
            elif [ "$choice" -eq $((${#networks[@]}+2)) ]; then
                # Usar padrão
                    SELECTED_NETWORK="mssql-network"
                return 0
            else
                # Usar rede selecionada
                selected_network="${networks[$((choice-1))]}"
                    SELECTED_NETWORK="$selected_network"
                return 0
            fi
        else
            error "Opção inválida! Digite um número entre 1 e $((${#networks[@]}+2))."
        fi
    done
}



# Função principal
main() {
    echo ""
    echo "======================================"
    echo "  MSSQL + SQLPad - Docker Compose"
    echo "======================================"
    echo ""
    
    # Verificar arquivo .env
    check_env_file
    
    # Selecionar contexto Docker
    CURRENT_CONTEXT=$(docker context show 2>/dev/null || echo "default")
    info "Contexto Docker atualmente ativo: $CURRENT_CONTEXT"

    select_docker_context "$CURRENT_CONTEXT"
    if [ -z "$SELECTED_CONTEXT" ]; then
        SELECTED_CONTEXT="$CURRENT_CONTEXT"
    fi

    if [ "$SELECTED_CONTEXT" != "$CURRENT_CONTEXT" ]; then
        warning "Alterando contexto Docker para '${SELECTED_CONTEXT}'..."
        docker context use "$SELECTED_CONTEXT" >/dev/null
        success "Contexto ativo atualizado para '${SELECTED_CONTEXT}'"
    else
        info "Mantendo contexto Docker '${CURRENT_CONTEXT}'"
    fi

    CURRENT_CONTEXT="$SELECTED_CONTEXT"
    local context
    context="$SELECTED_CONTEXT"
    info "Contexto Docker selecionado: $context"
    
    if is_remote_context "$context"; then
        IS_REMOTE=true
        warning "Detectado contexto Docker REMOTO"
        
        if get_remote_context_info "$context"; then
            local endpoint
            endpoint=$(docker context inspect "$context" --format '{{.Endpoints.docker.Host}}')
            info "Endpoint: $endpoint"
            info "Host remoto: ${REMOTE_USER}@${REMOTE_HOST}"
            
            # Detectar caminho remoto do projeto
            detect_remote_path
            
            if [ -n "$REMOTE_PATH" ]; then
                info "Caminho remoto do projeto: $REMOTE_PATH"
                
                # Sincronizar arquivos com o host remoto
                sync_project_to_remote
            else
                error "Não foi possível determinar o caminho remoto do projeto"
                exit 1
            fi
        fi
    else
        info "Detectado contexto Docker LOCAL"
    fi
    
    echo ""
    
    # Selecionar rede
    SELECTED_NETWORK=""
    select_network
    selected_network="$SELECTED_NETWORK"
    
    if [ -z "$selected_network" ]; then
        error "Nenhuma rede selecionada!"
        exit 1
    fi
    
    info "Rede selecionada: $selected_network"
    
    # Criar rede se não existir
    create_network_if_needed "$selected_network"
    
    # Atualizar variáveis de ambiente no arquivo .env local
    update_env_var "MSSQL_NETWORK" "$selected_network"
    update_env_var "SQLPAD_NETWORK" "$selected_network"
    success "Variáveis de rede atualizadas no .env"
    
    # Preparar volumes persistentes (executa no contexto selecionado)
    echo ""
    info "Preparando volumes persistentes..."
    prepare_persistent_volumes
    
    # Se for contexto remoto, sincronizar .env atualizado
    if [ "$IS_REMOTE" = true ]; then
        sync_env_to_remote
    fi
    
    echo ""
    info "Iniciando containers..."
    echo ""
    
    # Iniciar docker-compose
    if [ "$IS_REMOTE" = true ]; then
        # Para contextos remotos, navegar até o diretório remoto e executar
        if [ -n "$REMOTE_PATH" ]; then
            info "Executando Docker Compose no host remoto..."
            run_remote_compose up -d --build
        else
            warning "Caminho remoto não definido. Executando Docker Compose usando o contexto remoto atual."
            run_local_compose up -d --build
        fi
    else
        run_local_compose up -d
    fi
    
    echo ""
    success "Containers iniciados com sucesso!"
    echo ""
    
    # Aguardar health checks
    info "Aguardando containers ficarem healthy..."
    sleep 5
    
    # Exibir status
    echo ""
    run_local_compose ps
    echo ""
    
    # Informações de acesso
    echo "======================================"
    echo "  Informações de Acesso"
    echo "======================================"
    echo ""
    
    # Ler valores do .env sem executar comandos
    local sqlpad_port="$(get_env_var "SQLPAD_PORT")"
    local sqlpad_admin="$(get_env_var "SQLPAD_ADMIN")"
    local mssql_port="$(get_env_var "MSSQL_PORT")"

    sqlpad_port="${sqlpad_port:-3000}"
    sqlpad_admin="${sqlpad_admin:-admin@sqlpad.com}"
    mssql_port="${mssql_port:-1433}"
    
    if [ "$IS_REMOTE" = true ] && [ -n "$REMOTE_HOST" ]; then
        echo "SQLPad (Interface Web):"
        echo "  URL: http://${REMOTE_HOST}:${sqlpad_port}"
        echo "  Usuário: ${sqlpad_admin}"
        echo "  Senha: (conforme configurado no .env)"
        echo ""
        echo "SQL Server (Conexão Direta):"
        echo "  Host: ${REMOTE_HOST}"
        echo "  Porta: ${mssql_port}"
        echo "  Usuário: sa"
        echo "  Senha: (conforme configurado no .env)"
        echo ""
        echo "Host Remoto: ${REMOTE_USER}@${REMOTE_HOST}"
        echo "Caminho Remoto: ${REMOTE_PATH}"
    else
        echo "SQLPad (Interface Web):"
        echo "  URL: http://localhost:${sqlpad_port}"
        echo "  Usuário: ${sqlpad_admin}"
        echo "  Senha: (conforme configurado no .env)"
        echo ""
        echo "SQL Server (Conexão Direta):"
        echo "  Host: localhost"
        echo "  Porta: ${mssql_port}"
        echo "  Usuário: sa"
        echo "  Senha: (conforme configurado no .env)"
    fi
    
    echo ""
    echo "Rede Docker: $selected_network"
    echo "Contexto Docker: $(get_docker_context)"
    echo ""
    ensure_local_compose_cmd || true
    local compose_display="$LOCAL_COMPOSE_DISPLAY"
    if [ -z "$compose_display" ]; then
        compose_display="docker compose"
    fi

    local remote_compose_display="$REMOTE_COMPOSE_DISPLAY"
    if [ -z "$remote_compose_display" ]; then
        remote_compose_display="$compose_display"
    fi
    
    success "Setup concluído!"
    echo ""
    echo "Para ver os logs:"
    if [ "$IS_REMOTE" = true ]; then
        if [ -n "$REMOTE_PATH" ]; then
            echo "  ssh ${REMOTE_USER}@${REMOTE_HOST} 'cd ${REMOTE_PATH} && ${remote_compose_display} logs -f'"
        else
            echo "  ssh ${REMOTE_USER}@${REMOTE_HOST} '${remote_compose_display} logs -f'"
        fi
        echo "  ou use: ${compose_display} logs -f (o contexto Docker já aponta para o host remoto)"
    else
        echo "  ${compose_display} logs -f"
    fi
    echo ""
    echo "Para parar os containers:"
    if [ "$IS_REMOTE" = true ]; then
        if [ -n "$REMOTE_PATH" ]; then
            echo "  ssh ${REMOTE_USER}@${REMOTE_HOST} 'cd ${REMOTE_PATH} && ${remote_compose_display} down'"
        else
            echo "  ssh ${REMOTE_USER}@${REMOTE_HOST} '${remote_compose_display} down'"
        fi
        echo "  ou use: ${compose_display} down (o contexto Docker já aponta para o host remoto)"
    else
        echo "  ${compose_display} down"
    fi
    echo ""
}

# Executar função principal
main "$@"
