#!/usr/bin/env bash

set -euo pipefail

render_template() {
    local template_path="$1"
    local output_path="$2"
    shift 2

    local content
    content="$(<"$template_path")"

    local key value
    while [[ $# -gt 0 ]]; do
        key="$1"
        value="$2"
        shift 2
        content="${content//\{\{$key\}\}/$value}"
    done

    printf '%s\n' "$content" > "$output_path"
}

build_yaml_list_block() {
    local indent="$1"
    shift
    local values=("$@")
    local output=""
    local value

    if [[ ${#values[@]} -eq 0 ]]; then
        printf '%s[]' "$indent"
        return 0
    fi

    for value in "${values[@]}"; do
        output+="${indent}- ${value}"$'\n'
    done

    printf '%s' "${output%$'\n'}"
}

build_users_block() {
    local keep_default_user="$1"
    local default_user="$2"
    local primary_user="$3"
    local password_hash="$4"
    local shell_path="$5"
    local disable_password_login="$6"
    local groups_csv="$7"
    local ssh_key_content="$8"

    local block=""

    if [[ "$keep_default_user" == "true" && "$primary_user" != "$default_user" ]]; then
        block+="  - default"$'\n'
    fi

    block+="  - name: ${primary_user}"$'\n'
    block+="    shell: ${shell_path}"$'\n'
    block+="    sudo: ALL=(ALL) NOPASSWD:ALL"$'\n'
    block+="    groups: [${groups_csv}]"$'\n'

    if [[ "$disable_password_login" == "true" ]]; then
        block+="    lock_passwd: true"$'\n'
    else
        block+="    lock_passwd: false"$'\n'
        block+="    passwd: ${password_hash}"$'\n'
    fi

    if [[ -n "$ssh_key_content" ]]; then
        block+="    ssh_authorized_keys:"$'\n'
        block+="      - ${ssh_key_content}"$'\n'
    fi

    printf '%s' "${block%$'\n'}"
}

build_runcmd_block() {
    local output=""
    local command
    for command in "$@"; do
        output+="  - ${command}"$'\n'
    done
    printf '%s' "${output%$'\n'}"
}

build_dns_block() {
    local output=""
    local entry
    for entry in "$@"; do
        output+="        - ${entry}"$'\n'
    done
    printf '%s' "${output%$'\n'}"
}
