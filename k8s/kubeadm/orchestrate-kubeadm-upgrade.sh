#!/usr/bin/env bash

# Orquestrador seguro para upgrade de clusters Kubernetes com kubeadm
# - Descobre control planes e workers
# - Gera plano de execução em Markdown (ordem correta)
# - Opcionalmente executa o upgrade APENAS no node local
# Autor: DevOps Vanilla
# Data: 2026-03-06

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPGRADE_SCRIPT="$SCRIPT_DIR/upgrade-kubeadm.sh"

COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_NC='\033[0m'

TARGET_VERSION=""
TARGET_VERSION_NORM=""
OUTPUT_FILE=""
EXECUTE_LOCAL=false
MANAGE_DRAIN_WORKERS=false
AUTO_APPROVE=false
LOCAL_NODE_NAME=""
SSH_USER=""
SSH_KEY=""
SSH_PORT=""

declare -a CONTROL_PLANES=()
declare -a WORKERS=()
declare -A NODE_VERSION=()

info() {
    echo -e "${COLOR_BLUE}ℹ${COLOR_NC} $*"
}

ok() {
    echo -e "${COLOR_GREEN}✓${COLOR_NC} $*"
}

warn() {
    echo -e "${COLOR_YELLOW}⚠${COLOR_NC} $*"
}

err() {
    echo -e "${COLOR_RED}❌${COLOR_NC} $*"
}

print_header() {
    echo "============================================"
    echo "Kubernetes Upgrade Orchestrator (kubeadm)"
    echo "============================================"
}

usage() {
    cat <<EOF
Uso:
  bash ./$SCRIPT_NAME --target <vX.Y.Z> [opções]

Obrigatório:
  --target <vX.Y.Z>           Versão alvo (ex: v1.35.2 ou 1.35.2)

Opcionais:
  --output <arquivo.md>       Caminho do arquivo Markdown de plano (default: ./UPGRADE-PLAN-<timestamp>.md)
    --ssh-user <usuario>        Usuário SSH para gerar comandos remotos por nó no plano
    --ssh-key <caminho>         Chave SSH privada para compor os comandos remotos
    --ssh-port <porta>          Porta SSH (default: 22)
  --execute-local             Executa o upgrade SOMENTE no node local usando upgrade-kubeadm.sh
  --manage-drain-workers      Em --execute-local para worker, usa --manage-drain
  --yes                       Não pedir confirmações no orquestrador (repassa ao script local)
  -h, --help                  Mostrar ajuda

Exemplos:
  bash ./$SCRIPT_NAME --target v1.35.2
  bash ./$SCRIPT_NAME --target 1.35.2 --output ./upgrade-plan-v1.35.2.md
    bash ./$SCRIPT_NAME --target v1.35.2 --ssh-user ubuntu --ssh-key ~/.ssh/id_ed25519
  sudo bash ./$SCRIPT_NAME --target v1.35.2 --execute-local
EOF
}

normalize_version() {
    local raw="$1"
    echo "$raw" | sed 's/^v//'
}

validate_semver() {
    local v="$1"
    if [[ ! "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        err "Versão inválida: '$v'. Use vX.Y.Z (ex: v1.35.2)."
        exit 1
    fi
}

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        err "Comando obrigatório não encontrado: $cmd"
        exit 1
    fi
}

confirm() {
    local message="$1"
    if [ "$AUTO_APPROVE" = true ]; then
        info "Auto-approve ativo: $message"
        return 0
    fi

    read -rp "$message [s/N]: " reply
    if [[ ! "$reply" =~ ^[SsYy]$ ]]; then
        err "Operação cancelada pelo usuário."
        exit 0
    fi
}

contains() {
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        if [ "$item" = "$needle" ]; then
            return 0
        fi
    done
    return 1
}

shell_escape() {
    printf "%q" "$1"
}

build_node_command() {
    local node="$1"
    local role="$2"
    local node_cmd="sudo bash ./upgrade-kubeadm.sh --role $role --target v$TARGET_VERSION_NORM"

    if [ "$role" = "worker" ]; then
        node_cmd+=" --manage-drain"
    fi

    if [ -n "$SSH_USER" ]; then
        local ssh_port="22"
        [ -n "$SSH_PORT" ] && ssh_port="$SSH_PORT"

        local remote_cmd
        remote_cmd="cd $(shell_escape "$SCRIPT_DIR") && $node_cmd"

        local ssh_cmd="ssh -p $(shell_escape "$ssh_port") "
        if [ -n "$SSH_KEY" ]; then
            ssh_cmd+="-i $(shell_escape "$SSH_KEY") "
        fi
        ssh_cmd+="$(shell_escape "$SSH_USER")@$(shell_escape "$node")"
        ssh_cmd+=" $(shell_escape "$remote_cmd")"
        echo "$ssh_cmd"
        return
    fi

    echo "$node_cmd"
}

discover_local_node_name() {
    local -a candidates=()
    candidates+=("$(hostname -s 2>/dev/null || true)")
    candidates+=("$(hostname 2>/dev/null || true)")
    candidates+=("$(hostname -f 2>/dev/null || true)")

    local c
    for c in "${candidates[@]}"; do
        [ -n "$c" ] || continue
        if kubectl get node "$c" >/dev/null 2>&1; then
            echo "$c"
            return 0
        fi
    done

    for c in "${candidates[@]}"; do
        [ -n "$c" ] || continue
        local match
        match="$(kubectl get nodes -o name 2>/dev/null | sed 's#node/##' | grep -E "^${c}(\.|$)" | head -n1 || true)"
        if [ -n "$match" ]; then
            echo "$match"
            return 0
        fi
    done

    echo ""
}

discover_nodes() {
    info "Descobrindo nós do cluster..."

    mapfile -t CONTROL_PLANES < <(kubectl get nodes -l node-role.kubernetes.io/control-plane -o name 2>/dev/null | sed 's#node/##')

    local all_nodes
    mapfile -t all_nodes < <(kubectl get nodes -o name 2>/dev/null | sed 's#node/##')

    if [ "${#all_nodes[@]}" -eq 0 ]; then
        err "Nenhum node encontrado via kubectl."
        exit 1
    fi

    local node
    for node in "${all_nodes[@]}"; do
        if ! contains "$node" "${CONTROL_PLANES[@]}"; then
            WORKERS+=("$node")
        fi

        local version
        version="$(kubectl get node "$node" -o jsonpath='{.status.nodeInfo.kubeletVersion}' 2>/dev/null || true)"
        NODE_VERSION["$node"]="$version"
    done

    if [ "${#CONTROL_PLANES[@]}" -eq 0 ]; then
        warn "Não encontrei label node-role.kubernetes.io/control-plane."
        warn "Vou considerar apenas o primeiro node como control plane principal para plano manual."
        CONTROL_PLANES=("${all_nodes[0]}")

        WORKERS=()
        local n
        for n in "${all_nodes[@]}"; do
            if [ "$n" != "${CONTROL_PLANES[0]}" ]; then
                WORKERS+=("$n")
            fi
        done
    fi

    ok "Descoberta concluída: ${#CONTROL_PLANES[@]} control plane(s), ${#WORKERS[@]} worker(s)."
}

pick_first_control_plane() {
    if [ -n "$LOCAL_NODE_NAME" ] && contains "$LOCAL_NODE_NAME" "${CONTROL_PLANES[@]}"; then
        echo "$LOCAL_NODE_NAME"
        return
    fi

    echo "${CONTROL_PLANES[0]}"
}

print_summary() {
    local first_cp="$1"

    echo ""
    echo "Resumo do cluster"
    echo "-----------------"
    echo "Versão alvo: v$TARGET_VERSION_NORM"
    echo ""
    echo "Control planes:"

    local cp
    for cp in "${CONTROL_PLANES[@]}"; do
        local mark=""
        [ "$cp" = "$first_cp" ] && mark=" (primeiro control plane)"
        echo "  - $cp (${NODE_VERSION[$cp]:-desconhecida})$mark"
    done

    echo "Workers:"
    if [ "${#WORKERS[@]}" -eq 0 ]; then
        echo "  - (nenhum)"
    else
        local w
        for w in "${WORKERS[@]}"; do
            echo "  - $w (${NODE_VERSION[$w]:-desconhecida})"
        done
    fi

    echo ""
    warn "Regra: avançar no máximo 1 minor por vez (ex: 1.34 -> 1.35)."
    if [ -n "$SSH_USER" ]; then
        info "Comandos no plano serão gerados para execução remota via SSH (usuário: $SSH_USER)."
    fi
}

build_output_file() {
    if [ -n "$OUTPUT_FILE" ]; then
        echo "$OUTPUT_FILE"
        return
    fi

    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    echo "$SCRIPT_DIR/UPGRADE-PLAN-v${TARGET_VERSION_NORM}-${ts}.md"
}

write_markdown_plan() {
    local first_cp="$1"
    local plan_file="$2"

    cat > "$plan_file" <<EOF
# Kubernetes kubeadm Upgrade Plan

Generated on: $(date -Iseconds)
Target version: **v$TARGET_VERSION_NORM**

## Cluster Inventory

### Control planes
EOF

    local cp
    for cp in "${CONTROL_PLANES[@]}"; do
        local mark=""
        [ "$cp" = "$first_cp" ] && mark=" *(first control plane)*"
        echo "- \\`$cp\\` - ${NODE_VERSION[$cp]:-unknown}$mark" >> "$plan_file"
    done

    cat >> "$plan_file" <<EOF

### Workers
EOF

    if [ "${#WORKERS[@]}" -eq 0 ]; then
        echo "- *(none)*" >> "$plan_file"
    else
        local w
        for w in "${WORKERS[@]}"; do
            echo "- \\`$w\\` - ${NODE_VERSION[$w]:-unknown}" >> "$plan_file"
        done
    fi

    cat >> "$plan_file" <<EOF

## Safety Checklist (Before)

- [ ] etcd snapshot and/or control-plane backup completed
- [ ] Maintenance window approved
- [ ] Kubernetes apt repository for **v$TARGET_VERSION_NORM** configured on all nodes
- [ ] Monitoring and alerting reviewed
- [ ] Workload disruption plan validated (PDB, replicas, critical services)

## Execution Order

1. First control plane: \\`$first_cp\\`
2. Remaining control planes (one by one)
3. Workers (one by one, drain + uncordon)

## Commands Per Node

> Run the following on each respective node.

### 1) First control plane (\\`$first_cp\\`)

\\`\\`\\`bash
$(build_node_command "$first_cp" "control-plane-first")
\\`\\`\\`
EOF

    if [ "${#CONTROL_PLANES[@]}" -gt 1 ]; then
        cat >> "$plan_file" <<EOF

### 2) Additional control planes
EOF
        local cp2
        for cp2 in "${CONTROL_PLANES[@]}"; do
            if [ "$cp2" != "$first_cp" ]; then
                cat >> "$plan_file" <<EOF

Node: \\`$cp2\\`

\\`\\`\\`bash
$(build_node_command "$cp2" "control-plane")
\\`\\`\\`
EOF
            fi
        done
    fi

    if [ "${#WORKERS[@]}" -gt 0 ]; then
        cat >> "$plan_file" <<EOF

### 3) Workers
EOF

        local wrk
        for wrk in "${WORKERS[@]}"; do
            cat >> "$plan_file" <<EOF

Node: \\`$wrk\\`

\\`\\`\\`bash
$(build_node_command "$wrk" "worker")
\\`\\`\\`
EOF
        done
    fi

    cat >> "$plan_file" <<EOF

## Validation (After each node)

\\`\\`\\`bash
kubectl get nodes -o wide
kubectl get pods -A
\\`\\`\\`

## Final Validation

- [ ] All nodes report expected version
- [ ] All nodes are \\`Ready\\`
- [ ] Core components in \\`kube-system\\` are healthy
- [ ] Business workloads are healthy
EOF

    ok "Plano Markdown gerado: $plan_file"
}

run_local_upgrade_if_requested() {
    if [ "$EXECUTE_LOCAL" != true ]; then
        return
    fi

    if [ "${EUID}" -ne 0 ]; then
        err "--execute-local requer execução com root/sudo."
        exit 1
    fi

    if [ ! -x "$UPGRADE_SCRIPT" ]; then
        err "Script de upgrade local não encontrado ou sem permissão de execução: $UPGRADE_SCRIPT"
        exit 1
    fi

    local first_cp="$1"
    local role=""

    if contains "$LOCAL_NODE_NAME" "${CONTROL_PLANES[@]}"; then
        if [ "$LOCAL_NODE_NAME" = "$first_cp" ]; then
            role="control-plane-first"
        else
            role="control-plane"
        fi
    elif contains "$LOCAL_NODE_NAME" "${WORKERS[@]}"; then
        role="worker"
    else
        err "Não consegui determinar o papel do node local '$LOCAL_NODE_NAME'."
        exit 1
    fi

    local cmd=("$UPGRADE_SCRIPT" "--role" "$role" "--target" "v$TARGET_VERSION_NORM")
    if [ "$role" = "worker" ] && [ "$MANAGE_DRAIN_WORKERS" = true ]; then
        cmd+=("--manage-drain")
    fi
    if [ "$AUTO_APPROVE" = true ]; then
        cmd+=("--yes")
    fi

    echo ""
    warn "Modo --execute-local: será executado apenas no node local '$LOCAL_NODE_NAME' com role '$role'."
    confirm "Deseja iniciar o upgrade local agora?"

    "${cmd[@]}"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target)
                TARGET_VERSION="$2"
                shift 2
                ;;
            --output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --ssh-user)
                SSH_USER="$2"
                shift 2
                ;;
            --ssh-key)
                SSH_KEY="$2"
                shift 2
                ;;
            --ssh-port)
                SSH_PORT="$2"
                shift 2
                ;;
            --execute-local)
                EXECUTE_LOCAL=true
                shift
                ;;
            --manage-drain-workers)
                MANAGE_DRAIN_WORKERS=true
                shift
                ;;
            --yes)
                AUTO_APPROVE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                err "Parâmetro desconhecido: $1"
                usage
                exit 1
                ;;
        esac
    done

    if [ -z "$TARGET_VERSION" ]; then
        err "Parâmetro obrigatório ausente: --target"
        usage
        exit 1
    fi

    TARGET_VERSION_NORM="$(normalize_version "$TARGET_VERSION")"
    validate_semver "$TARGET_VERSION_NORM"

    if [ -n "$SSH_KEY" ] && [ -z "$SSH_USER" ]; then
        err "--ssh-key requer também --ssh-user."
        exit 1
    fi

    if [ -n "$SSH_PORT" ] && [[ ! "$SSH_PORT" =~ ^[0-9]+$ ]]; then
        err "--ssh-port deve ser numérico."
        exit 1
    fi

    if [ -n "$SSH_KEY" ] && [ ! -f "$SSH_KEY" ]; then
        warn "Arquivo de chave SSH não encontrado localmente: $SSH_KEY"
        warn "O plano será gerado mesmo assim; revise o caminho antes de executar."
    fi
}

main() {
    print_header
    parse_args "$@"

    require_cmd kubectl

    if ! kubectl version --short >/dev/null 2>&1; then
        err "kubectl não conseguiu acessar o cluster. Verifique kubeconfig/contexto."
        exit 1
    fi

    LOCAL_NODE_NAME="$(discover_local_node_name)"
    if [ -z "$LOCAL_NODE_NAME" ]; then
        warn "Não foi possível identificar automaticamente o node local no cluster."
        warn "Planejamento continuará normalmente; execução local pode não funcionar."
    else
        info "Node local detectado: $LOCAL_NODE_NAME"
    fi

    discover_nodes

    local first_cp
    first_cp="$(pick_first_control_plane)"

    print_summary "$first_cp"

    local plan_file
    plan_file="$(build_output_file)"
    write_markdown_plan "$first_cp" "$plan_file"

    run_local_upgrade_if_requested "$first_cp"

    echo ""
    ok "Orquestração concluída."
    info "Próximo passo: execute os comandos do plano em ordem, um node por vez."
}

main "$@"
