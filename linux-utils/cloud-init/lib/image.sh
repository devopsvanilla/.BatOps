#!/usr/bin/env bash

set -euo pipefail

create_seed_image() {
    local output_iso="$1"
    local volume_label="$2"
    local user_data_path="$3"
    local meta_data_path="$4"
    local network_config_path="${5:-}"

    mkdir -p "$(dirname "$output_iso")"

    if command -v cloud-localds >/dev/null 2>&1; then
        if [[ -n "$network_config_path" && -f "$network_config_path" ]]; then
            cloud-localds --network-config="$network_config_path" "$output_iso" "$user_data_path" "$meta_data_path"
        else
            cloud-localds "$output_iso" "$user_data_path" "$meta_data_path"
        fi
        return 0
    fi

    local iso_builder=""
    if command -v genisoimage >/dev/null 2>&1; then
        iso_builder="genisoimage"
    elif command -v mkisofs >/dev/null 2>&1; then
        iso_builder="mkisofs"
    elif command -v xorriso >/dev/null 2>&1; then
        iso_builder="xorriso"
    fi

    [[ -n "$iso_builder" ]] || return 1

    local temp_dir
    temp_dir="$(mktemp -d)"
    trap 'rm -rf "$temp_dir"' RETURN
    local iso_inputs=("$temp_dir/user-data" "$temp_dir/meta-data")

    cp "$user_data_path" "$temp_dir/user-data"
    cp "$meta_data_path" "$temp_dir/meta-data"

    if [[ -n "$network_config_path" && -f "$network_config_path" ]]; then
        cp "$network_config_path" "$temp_dir/network-config"
        iso_inputs+=("$temp_dir/network-config")
    fi

    case "$iso_builder" in
        genisoimage|mkisofs)
            "$iso_builder" -output "$output_iso" -volid "$volume_label" -joliet -rock "${iso_inputs[@]}" >/dev/null 2>&1
            ;;
        xorriso)
            xorriso -as mkisofs -output "$output_iso" -volid "$volume_label" -joliet -rock "${iso_inputs[@]}" >/dev/null 2>&1
            ;;
    esac
}
