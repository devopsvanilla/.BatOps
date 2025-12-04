#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
ENV_SAMPLE="$PROJECT_DIR/.env-sample"
ENV_FILE="$PROJECT_DIR/.env"
DRY_RUN="false"
USE_MOCK="false"
FORCE_DEFAULT_NETWORK="false"

usage() {
  cat <<'TXT'
Script de implantação interativa para o stack OpenLDAP + phpLDAPadmin.

Opções:
  --dry-run    Executa todas as etapas sem aplicar mudanças (útil para testes).
  --mock       Usa dados fictícios para contexts/redes (depuração sem Docker).
  -h, --help   Mostra esta ajuda.
TXT
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --mock)
      USE_MOCK="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERRO] Opção desconhecida: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "[ERRO] docker-compose.yml não encontrado em $PROJECT_DIR" >&2
  exit 1
fi

require_command() {
  if [[ "$USE_MOCK" == "true" ]]; then
    return
  fi
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERRO] Comando '$1' não encontrado. Instale-o e tente novamente." >&2
    exit 1
  fi
}

require_command docker

ensure_env_file() {
  if [[ -f "$ENV_FILE" ]]; then
    return
  fi
  if [[ ! -f "$ENV_SAMPLE" ]]; then
    echo "[ERRO] .env-sample não foi encontrado para gerar o .env" >&2
    exit 1
  fi
  cp "$ENV_SAMPLE" "$ENV_FILE"
  echo "[INFO] Arquivo .env criado a partir de .env-sample." >&2
}

ensure_env_file

escape_sed() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

update_env_var() {
  local key="$1"
  local value="$2"
  local normalized="$value"
  if [[ "$normalized" =~ [[:space:]] ]]; then
    normalized="\"$normalized\""
  fi
  local escaped
  escaped=$(escape_sed "$normalized")
  if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
    perl -0pi -e 's/^'"$key"'=.*/'"$key=$escaped"'/m' "$ENV_FILE"
  else
    printf "\n%s=%s\n" "$key" "$normalized" >> "$ENV_FILE"
  fi
}

remove_env_var() {
  local key="$1"
  if [[ -f "$ENV_FILE" ]]; then
    perl -0pi -e 's/^'"$key"'=.*\n?//m' "$ENV_FILE"
  fi
}

run_docker() {
  if [[ "$USE_MOCK" == "true" ]]; then
    echo "[MOCK] docker $*"
    return 0
  fi
  docker "$@"
}

current_context=""
context_rows=()

load_contexts() {
  if [[ "$USE_MOCK" == "true" ]]; then
    current_context="default"
    context_rows=(
      "default|unix:///var/run/docker.sock|Contexto local padrão"
      "remote-lab|ssh://lab@10.0.0.10|Servidor remoto (lab)"
    )
    return
  fi
  current_context=$(docker context show 2>/dev/null || echo "default")
  mapfile -t context_rows < <(docker context ls --format '{{.Name}}|{{.DockerEndpoint}}|{{.Description}}')
  if [[ ${#context_rows[@]} -eq 0 ]]; then
    echo "[ERRO] Nenhum contexto Docker encontrado. Crie um contexto antes de prosseguir." >&2
    exit 1
  fi
}

load_contexts

draw_context_menu() {
  printf '\nContextos Docker disponíveis:\n'
  local index=1
  for row in "${context_rows[@]}"; do
    IFS='|' read -r name endpoint description <<<"$row"
    local marker=" "
    if [[ "$name" == "$current_context" ]]; then
      marker="*"
    fi
    printf "  [%d] %s %s\n      Endpoint: %s\n      Descrição: %s\n" "$index" "$marker" "$name" "$endpoint" "${description:-<sem descrição>}"
    ((index++))
  done
  echo "  [ENTER] Manter contexto atual ($current_context)"
}

select_context() {
  draw_context_menu
  local selection
  read -rp $'Escolha o número do contexto desejado (ENTER mantém atual): ' selection
  local chosen="$current_context"
  if [[ -n "$selection" ]]; then
    if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
      echo "[ERRO] Entrada inválida." >&2
      exit 1
    fi
    local idx=$((selection-1))
    if (( idx < 0 || idx >= ${#context_rows[@]} )); then
      echo "[ERRO] Número fora da faixa." >&2
      exit 1
    fi
    IFS='|' read -r chosen _ _ <<<"${context_rows[$idx]}"
  fi
  if [[ "$chosen" != "$current_context" ]]; then
    echo "[INFO] Alterando contexto padrão para '$chosen'."
    if [[ "$USE_MOCK" == "true" ]]; then
      current_context="$chosen"
    else
      docker context use "$chosen"
      current_context="$chosen"
    fi
  else
    echo "[INFO] Mantendo contexto '$current_context'."
  fi
  ACTIVE_CONTEXT="$current_context"
}

ACTIVE_CONTEXT=""
select_context

list_networks() {
  network_rows=()
  if [[ "$USE_MOCK" == "true" ]]; then
    network_rows=(
      "bridge|bridge|local"
      "lab-net|overlay|swarm"
    )
    return
  fi
  mapfile -t network_rows < <(docker network ls --format '{{.Name}}|{{.Driver}}|{{.Scope}}')
}

prompt_network_selection() {
  list_networks
  printf "\nRedes disponíveis no contexto '%s':\n" "$ACTIVE_CONTEXT"
  local index=1
  for row in "${network_rows[@]}"; do
    IFS='|' read -r name driver scope <<<"$row"
    printf "  [%d] %s (driver=%s, escopo=%s)\n" "$index" "$name" "$driver" "$scope"
    ((index++))
  done
  echo "  [0] Criar nova rede" 
  echo "  [ENTER] Usar rede padrão gerenciada pelo Docker Compose"
  local selection
  read -rp $'Escolha a rede desejada: ' selection
  if [[ -z "$selection" ]]; then
    FORCE_DEFAULT_NETWORK="true"
    echo "[INFO] Docker Compose criará/gerenciará a rede padrão."
    return
  fi
  if [[ "$selection" == "0" ]]; then
    read -rp "Informe o nome da nova rede: " new_network
    if [[ -z "$new_network" ]]; then
      echo "[ERRO] Nome da rede não pode ser vazio." >&2
      exit 1
    fi
    create_network "$new_network"
    SELECTED_NETWORK="$new_network"
    NETWORK_EXTERNAL="true"
    return
  fi
  if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
    echo "[ERRO] Entrada inválida." >&2
    exit 1
  fi
  local idx=$((selection-1))
  if (( idx < 0 || idx >= ${#network_rows[@]} )); then
    echo "[ERRO] Número fora da faixa." >&2
    exit 1
  fi
  IFS='|' read -r SELECTED_NETWORK driver scope <<<"${network_rows[$idx]}"
  NETWORK_EXTERNAL="true"
  echo "[INFO] Rede selecionada: $SELECTED_NETWORK (driver=$driver)."
}

create_network() {
  local name="$1"
  echo "[INFO] Criando rede '$name'."
  if [[ "$USE_MOCK" == "true" ]]; then
    network_rows+=("$name|bridge|local")
    return
  fi
  docker network create "$name" >/dev/null
}

SELECTED_NETWORK=""
NETWORK_EXTERNAL="false"

prompt_network_selection

prepare_network_env() {
  if [[ "$FORCE_DEFAULT_NETWORK" == "true" ]]; then
    remove_env_var "LDAP_DOCKER_NETWORK_NAME"
    remove_env_var "LDAP_DOCKER_NETWORK_EXTERNAL"
    return
  fi
  update_env_var "LDAP_DOCKER_NETWORK_NAME" "$SELECTED_NETWORK"
  if [[ "$NETWORK_EXTERNAL" == "true" ]]; then
    update_env_var "LDAP_DOCKER_NETWORK_EXTERNAL" "true"
  else
    update_env_var "LDAP_DOCKER_NETWORK_EXTERNAL" "false"
  fi
}

prepare_network_env

ensure_bind_dirs() {
  local db_dir="$PROJECT_DIR/data/slapd/database"
  local cfg_dir="$PROJECT_DIR/data/slapd/config"
  mkdir -p "$db_dir" "$cfg_dir"
}

if [[ "$USE_MOCK" != "true" ]]; then
  ensure_bind_dirs
fi

summary() {
  printf '\nResumo da implantação:\n'
  echo "  Contexto ativo : $ACTIVE_CONTEXT"
  if [[ "$FORCE_DEFAULT_NETWORK" == "true" ]]; then
    echo "  Rede          : padrão gerenciada pelo Compose"
  else
    echo "  Rede          : $SELECTED_NETWORK (external=$NETWORK_EXTERNAL)"
  fi
  echo "  Arquivo .env  : $ENV_FILE"
  echo "  Docker Compose: $COMPOSE_FILE"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  Modo dry-run  : nenhuma alteração será aplicada"
  fi
  if [[ "$USE_MOCK" == "true" ]]; then
    echo "  Modo mock     : comandos Docker reais foram simulados"
  fi
}

summary

confirm_and_deploy() {
  local confirm
  read -rp $'Prosseguir com a implantação? [S/n]: ' confirm
  confirm="${confirm:-S}"
  if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
    echo "[INFO] Implantação cancelada pelo usuário."
    exit 0
  fi
  local compose_cmd=(docker compose --project-directory "$PROJECT_DIR" --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d)
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] ${compose_cmd[*]}"
    return
  fi
  if [[ "$USE_MOCK" == "true" ]]; then
    echo "[MOCK] ${compose_cmd[*]}"
    echo "[MOCK] Implantação simulada com sucesso."
    return
  fi
  "${compose_cmd[@]}"
  echo "[SUCESSO] Stack implantado. Use 'docker compose ps' para verificar o status."
}

confirm_and_deploy
