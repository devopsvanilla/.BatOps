#!/usr/bin/env bash

set -euo pipefail

list_profile_files() {
    local profile_dir="$1"
    find "$profile_dir" -maxdepth 1 -type f -name '*.yaml' | sort
}

profile_exists() {
    local profile_dir="$1"
    local profile_name="$2"
    [[ -f "$profile_dir/$profile_name.yaml" ]]
}

resolve_profile_path() {
    local profile_dir="$1"
    local profile_name="$2"

    if [[ -f "$profile_name" ]]; then
        printf '%s' "$profile_name"
        return 0
    fi

    if profile_exists "$profile_dir" "$profile_name"; then
        printf '%s' "$profile_dir/$profile_name.yaml"
        return 0
    fi

    return 1
}

yaml_get_scalar() {
    local file_path="$1"
    local key="$2"

    awk -v target="$key" '
        function trim(value) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            return value
        }
        {
            line = $0
            sub(/[[:space:]]+#.*$/, "", line)
            if (line ~ /^[[:space:]]*$/) {
                next
            }

            split(line, parts, ":")
            key_part = trim(parts[1])
            if (key_part != target) {
                next
            }

            sub(/^[^:]+:[[:space:]]*/, "", line)
            line = trim(line)
            gsub(/^"|"$/, "", line)
            print line
            exit
        }
    ' "$file_path"
}

yaml_get_list() {
    local file_path="$1"
    local key="$2"

    awk -v target="$key" '
        function trim(value) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            return value
        }
        {
            raw = $0
            line = raw
            sub(/[[:space:]]+#.*$/, "", line)
            if (line ~ /^[[:space:]]*$/) {
                next
            }

            if (!collect) {
                split(line, parts, ":")
                key_part = trim(parts[1])
                if (key_part == target) {
                    collect = 1
                    list_indent = match(raw, /[^[:space:]]/) - 1
                }
                next
            }

            current_indent = match(raw, /[^[:space:]]/) - 1
            if (current_indent <= list_indent) {
                exit
            }

            if (line ~ /^[[:space:]]*-[[:space:]]*/) {
                sub(/^[[:space:]]*-[[:space:]]*/, "", line)
                print trim(line)
            }
        }
    ' "$file_path"
}
