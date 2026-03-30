#!/usr/bin/env bash

# Script guiado para upgrade seguro de clusters Kubernetes com kubeadm
# Suporta execução em control planes e workers
# Autor: DevOps Vanilla
# Data: 2026-03-06

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_NC='\033[0m'

ROLE=""
TARGET_VERSION=""
NODE_NAME="$(hostname -s 2>/dev/null || hostname)"
AUTO_APPROVE=false
MANAGE_DRAIN=false

print_header() {
    echo "======================================"
    echo "Kubernetes Safe Upgrade (kubeadm)"
    echo "======================================"
}

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

usage() {
    cat <<EOF
Uso:
  sudo bash ./$SCRIPT_NAME --role <control-plane-first|control-plane|worker> --target <vX.Y.Z>

Parâmetros obrigatórios:
  --role       Papel do node durante o upgrade:
               - control-plane-first : primeiro control plane (executa upgrade apply)
               - control-plane       : control planes adicionais (executa upgrade node)
               - worker              : worker nodes (executa upgrade node)
  --target     Versão alvo Kubernetes (ex: v1.35.2 ou 1.35.2)

Parâmetros opcionais:
  --node-name <nome>   Nome do node para operações de drain/uncordon (default: hostname)
  --manage-drain       Faz drain/uncordon automaticamente para role=worker (requer kubectl funcional)
  --yes                Não solicitar confirmações interativas
  -h, --help           Exibe esta ajuda

Exemplos:
  sudo bash ./$SCRIPT_NAME --role control-plane-first --target v1.35.2
  sudo bash ./$SCRIPT_NAME --role control-plane --target 1.35.2
  sudo bash ./$SCRIPT_NAME --role worker --target 1.35.2 --manage-drain
EOF
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

normalize_version() {
    local raw="$1"
    echo "$raw" | sed 's/^v//' 
}

version_to_minor() {
    local v="$1"
    awk -F. '{print $1"."$2}' <<< "$v"
}

version_to_major() {
    local v="$1"
    awk -F. '{print $1}' <<< "$v"
}

version_to_minor_number() {
    local v="$1"
    awk -F. '{print $2}' <<< "$v"
}

validate_semver() {
    local v="$1"
    if [[ ! "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        err "Versão inválida: '$v'. Use o formato vX.Y.Z (ex: v1.35.2)."
        exit 1
    fi
}

require_root() {
    if [ "${EUID}" -ne 0 ]; then
        err "Este script precisa ser executado como root (sudo)."
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

detect_pkg_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
        return
    fi

    err "Distribuição não suportada por este script (esperado apt/Ubuntu)."
    err "Para segurança, o script não executará upgrades em gerenciador de pacotes desconhecido."
    exit 1
}

apt_find_version() {
    local pkg="$1"
    local target="$2"
    local target_re
    target_re="^${target//./\\.}(-|$)"

    local candidate
    candidate="$(apt-cache madison "$pkg" | awk '{print $3}' | grep -E "$target_re" | head -n1 || true)"

    if [ -z "$candidate" ]; then
        err "Não encontrei versão '$target' para pacote '$pkg'."
        err "Verifique se o repositório da versão alvo já está configurado em /etc/apt/sources.list.d/."
        exit 1
    fi

    echo "$candidate"
}

apt_install_pkg_version() {
    local pkg="$1"
    local target="$2"

    apt-get update -y

    local resolved_version
    resolved_version="$(apt_find_version "$pkg" "$target")"

    info "Instalando $pkg=$resolved_version"
    apt-get install -y "$pkg=$resolved_version"
}

hold_core_packages() {
    apt-mark hold kubeadm kubelet kubectl >/dev/null 2>&1 || true
}

restart_kubelet() {
    systemctl daemon-reload
    systemctl restart kubelet
    sleep 2
    systemctl is-active --quiet kubelet && ok "kubelet ativo" || {
        err "kubelet não está ativo após restart"
        exit 1
    }
}

preflight_checks() {
    require_root
    require_cmd kubeadm
    require_cmd kubelet
    require_cmd systemctl

    local current_raw
    current_raw="$(kubeadm version -o short 2>/dev/null || true)"
    if [ -z "$current_raw" ]; then
        err "Não foi possível detectar versão atual do kubeadm."
        exit 1
    fi

    CURRENT_VERSION="$(normalize_version "$current_raw")"

    validate_semver "$CURRENT_VERSION"
    validate_semver "$TARGET_VERSION"

    local cur_major cur_minor tar_major tar_minor
    cur_major="$(version_to_major "$CURRENT_VERSION")"
    cur_minor="$(version_to_minor_number "$CURRENT_VERSION")"
    tar_major="$(version_to_major "$TARGET_VERSION")"
    tar_minor="$(version_to_minor_number "$TARGET_VERSION")"

    if [ "$cur_major" != "$tar_major" ]; then
        err "Upgrade entre majors não suportado por este fluxo: $CURRENT_VERSION -> $TARGET_VERSION"
        exit 1
    fi

    if [ "$tar_minor" -lt "$cur_minor" ]; then
        err "Downgrade não permitido: $CURRENT_VERSION -> $TARGET_VERSION"
        exit 1
    fi

    if [ "$tar_minor" -gt $((cur_minor + 1)) ]; then
        err "Upgrade inseguro: só é permitido avançar 1 minor por vez."
        err "Atual: v$CURRENT_VERSION | Alvo: v$TARGET_VERSION"
        exit 1
    fi

    if [ "$CURRENT_VERSION" = "$TARGET_VERSION" ]; then
        warn "Versão atual já é a versão alvo (v$TARGET_VERSION)."
        confirm "Deseja apenas revalidar e reinstalar pacotes desta versão?"
    fi

    if [ "$ROLE" != "worker" ] && [ ! -f /etc/kubernetes/admin.conf ]; then
        err "admin.conf não encontrado. Este node não parece ser control plane inicializado."
        exit 1
    fi

    if [ "$MANAGE_DRAIN" = true ]; then
        require_cmd kubectl
    fi
}

show_plan() {
    echo ""
    echo "Resumo do plano de upgrade"
    echo "--------------------------"
    echo "Role do node      : $ROLE"
    echo "Node name         : $NODE_NAME"
    echo "Versão atual      : v$CURRENT_VERSION"
    echo "Versão alvo       : v$TARGET_VERSION"
    echo "Gerenciar drain   : $MANAGE_DRAIN"
    echo ""

    if [ "$ROLE" = "control-plane-first" ]; then
        echo "Etapas:"
        echo "  1) Atualizar kubeadm"
        echo "  2) Executar kubeadm upgrade plan"
        echo "  3) Executar kubeadm upgrade apply"
        echo "  4) Atualizar kubelet/kubectl"
        echo "  5) Reiniciar kubelet"
    elif [ "$ROLE" = "control-plane" ]; then
        echo "Etapas:"
        echo "  1) Atualizar kubeadm"
        echo "  2) Executar kubeadm upgrade node"
        echo "  3) Atualizar kubelet/kubectl"
        echo "  4) Reiniciar kubelet"
    else
        echo "Etapas:"
        if [ "$MANAGE_DRAIN" = true ]; then
            echo "  1) Drain do worker"
        fi
        echo "  2) Atualizar kubeadm"
        echo "  3) Executar kubeadm upgrade node"
        echo "  4) Atualizar kubelet"
        echo "  5) Reiniciar kubelet"
        if [ "$MANAGE_DRAIN" = true ]; then
            echo "  6) Uncordon do worker"
        fi
    fi

    echo ""
    warn "Garanta backup/etcd snapshot e janela de manutenção antes de continuar."
    confirm "Deseja prosseguir com este node agora?"
}

upgrade_control_plane_first() {
    info "[1/5] Atualizando kubeadm"
    apt_install_pkg_version "kubeadm" "$TARGET_VERSION"

    info "[2/5] Exibindo plano de upgrade"
    kubeadm upgrade plan

    confirm "Executar 'kubeadm upgrade apply v$TARGET_VERSION' agora?"
    info "[3/5] Aplicando upgrade no primeiro control plane"
    kubeadm upgrade apply -y "v$TARGET_VERSION"

    info "[4/5] Atualizando kubelet e kubectl"
    apt_install_pkg_version "kubelet" "$TARGET_VERSION"
    apt_install_pkg_version "kubectl" "$TARGET_VERSION"
    hold_core_packages

    info "[5/5] Reiniciando kubelet"
    restart_kubelet
}

upgrade_control_plane_additional() {
    info "[1/4] Atualizando kubeadm"
    apt_install_pkg_version "kubeadm" "$TARGET_VERSION"

    confirm "Executar 'kubeadm upgrade node' agora?"
    info "[2/4] Aplicando upgrade no control plane adicional"
    kubeadm upgrade node

    info "[3/4] Atualizando kubelet e kubectl"
    apt_install_pkg_version "kubelet" "$TARGET_VERSION"
    apt_install_pkg_version "kubectl" "$TARGET_VERSION"
    hold_core_packages

    info "[4/4] Reiniciando kubelet"
    restart_kubelet
}

upgrade_worker() {
    local drained=false

    if [ "$MANAGE_DRAIN" = true ]; then
        info "[1/6] Realizando drain do worker '$NODE_NAME'"
        kubectl drain "$NODE_NAME" --ignore-daemonsets --delete-emptydir-data
        drained=true
    else
        warn "Drain automático desativado. Recomendado drenar este node antes do upgrade."
        confirm "Confirmar que o node já foi drenado (ou que você aceita continuar sem drain)?"
    fi

    info "[2/6] Atualizando kubeadm"
    apt_install_pkg_version "kubeadm" "$TARGET_VERSION"

    confirm "Executar 'kubeadm upgrade node' agora?"
    info "[3/6] Aplicando upgrade no worker"
    kubeadm upgrade node

    info "[4/6] Atualizando kubelet"
    apt_install_pkg_version "kubelet" "$TARGET_VERSION"

    if dpkg -s kubectl >/dev/null 2>&1; then
        info "[5/6] kubectl detectado no worker, atualizando também"
        apt_install_pkg_version "kubectl" "$TARGET_VERSION"
    else
        info "[5/6] kubectl não instalado no worker, mantendo sem kubectl"
    fi

    hold_core_packages

    info "[6/6] Reiniciando kubelet"
    restart_kubelet

    if [ "$drained" = true ]; then
        info "Reabilitando agendamento com uncordon"
        kubectl uncordon "$NODE_NAME"
        ok "Node '$NODE_NAME' liberado com sucesso"
    fi
}

post_checks() {
    echo ""
    ok "Upgrade local concluído para role '$ROLE'."

    if command -v kubectl >/dev/null 2>&1; then
        echo ""
        info "Validação sugerida (executar de um control plane):"
        echo "  kubectl get nodes -o wide"
        echo "  kubectl get pods -A"
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --role)
                ROLE="$2"
                shift 2
                ;;
            --target)
                TARGET_VERSION="$(normalize_version "$2")"
                shift 2
                ;;
            --node-name)
                NODE_NAME="$2"
                shift 2
                ;;
            --manage-drain)
                MANAGE_DRAIN=true
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

    if [ -z "$ROLE" ] || [ -z "$TARGET_VERSION" ]; then
        err "Parâmetros obrigatórios ausentes."
        usage
        exit 1
    fi

    case "$ROLE" in
        control-plane-first|control-plane|worker) ;;
        *)
            err "Role inválida: $ROLE"
            usage
            exit 1
            ;;
    esac
}

main() {
    print_header
    parse_args "$@"

    PKG_MANAGER="$(detect_pkg_manager)"
    if [ "$PKG_MANAGER" != "apt" ]; then
        err "Gerenciador de pacotes não suportado: $PKG_MANAGER"
        exit 1
    fi

    preflight_checks
    show_plan

    case "$ROLE" in
        control-plane-first)
            upgrade_control_plane_first
            ;;
        control-plane)
            upgrade_control_plane_additional
            ;;
        worker)
            upgrade_worker
            ;;
    esac

    post_checks
}

main "$@"
