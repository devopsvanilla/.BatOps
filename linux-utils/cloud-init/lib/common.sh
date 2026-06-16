#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

fail() {
    log_error "$*"
    exit 1
}

trim() {
    local value="$1"
    value="${value#${value%%[![:space:]]*}}"
    value="${value%${value##*[![:space:]]}}"
    printf '%s' "$value"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

join_by() {
    local delimiter="$1"
    shift || true
    local first=1
    local item
    for item in "$@"; do
        if [[ $first -eq 1 ]]; then
            printf '%s' "$item"
            first=0
        else
            printf '%s%s' "$delimiter" "$item"
        fi
    done
}

slugify() {
    local value="$1"
    value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
    value="$(printf '%s' "$value" | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
    printf '%s' "$value"
}

prompt_with_default() {
    local prompt_text="$1"
    local default_value="${2:-}"
    local response

    if [[ -n "$default_value" ]]; then
        read -r -p "$prompt_text [$default_value]: " response
        response="${response:-$default_value}"
    else
        read -r -p "$prompt_text: " response
    fi

    printf '%s' "$response"
}

prompt_secret_optional() {
    local prompt_text="$1"
    local response
    read -r -s -p "$prompt_text: " response
    echo
    printf '%s' "$response"
}

prompt_choice() {
    local prompt_text="$1"
    local default_value="$2"
    shift 2
    local options=("$@")
    local response

    echo "$prompt_text" >&2
    local option
    for option in "${options[@]}"; do
        echo "  - $option" >&2
    done

    while true; do
        read -r -p "Escolha [$default_value]: " response
        response="${response:-$default_value}"
        for option in "${options[@]}"; do
            if [[ "$response" == "$option" ]]; then
                printf '%s' "$response"
                return 0
            fi
        done
        log_warn "Valor inválido: $response"
    done
}

confirm() {
    local prompt_text="$1"
    local default_value="${2:-y}"
    local response
    local suffix="[Y/n]"

    if [[ "$default_value" =~ ^[Nn]$ ]]; then
        suffix="[y/N]"
    fi

    read -r -p "$prompt_text $suffix: " response
    response="${response:-$default_value}"

    [[ "$response" =~ ^[Yy]$ ]]
}

validate_ipv4() {
    local ip="$1"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

    local octet
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        ((octet >= 0 && octet <= 255)) || return 1
    done

    return 0
}

validate_cidr() {
    local cidr="$1"
    [[ "$cidr" =~ ^[0-9]{1,2}$ ]] || return 1
    ((cidr >= 1 && cidr <= 32))
}

validate_hostname() {
    local hostname="$1"
    [[ ${#hostname} -le 253 ]] || return 1
    [[ "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]
}

validate_username() {
    local username="$1"
    [[ ${#username} -le 32 ]] || return 1
    [[ "$username" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]
}

yaml_bool() {
    local value
    value="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    case "$value" in
        true|yes|y|1) printf 'true' ;;
        false|no|n|0) printf 'false' ;;
        *) fail "Valor booleano inválido: $1" ;;
    esac
}

generate_password_hash() {
    local password="$1"

    if command_exists openssl; then
        openssl passwd -6 "$password"
        return 0
    fi

    if command_exists mkpasswd; then
        mkpasswd --method=SHA-512 "$password"
        return 0
    fi

    fail "Nenhum gerador de hash de senha encontrado. Instale openssl ou whois (mkpasswd)."
}
