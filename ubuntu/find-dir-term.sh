#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Uso:
  find-dir-term.sh --term <termo|padrao> [--base <diretorio_base>]

Descrição:
  Lista a primeira ocorrência do diretório que combine com --term
  para cada caminho analisado.

Regras de --term:
  - *termo   => nomes que terminam com "termo"
  - termo*   => nomes que começam com "termo"
  - *termo*  => nomes que contenham "termo"
  - termo    => nomes exatamente iguais a "termo"

Comportamento:
  - Se receber caminhos pela entrada padrão (stdin), processa essas linhas.
  - Caso contrário, usa find no [diretorio_base] (padrão: .).
  - Remove duplicados automaticamente na saída.

Exemplos:
  ./find-dir-term.sh --term doc --base .
  ./find-dir-term.sh --term 'doc*'
  ./find-dir-term.sh --term '*doc'
  ./find-dir-term.sh --term '*doc*'
  cat lista.txt | ./find-dir-term.sh --term doc
EOF
}

term=""
base_dir="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --term)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Erro: --term exige um valor." >&2
        usage
        exit 1
      fi
      term="$2"
      shift 2
      ;;
    --base)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Erro: --base exige um valor." >&2
        usage
        exit 1
      fi
      base_dir="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Erro: parâmetro desconhecido: $1" >&2
      usage
      exit 1
      ;;
  esac
done

declare -A seen

emit_unique() {
  local value="$1"
  if [[ -z "${seen[$value]+x}" ]]; then
    seen["$value"]=1
    printf '%s\n' "$value"
  fi
}

matches_term() {
  local name="$1"
  local pattern="$2"
  local core

  if [[ "$pattern" == \** && "$pattern" == *\* ]]; then
    core="${pattern#\*}"
    core="${core%\*}"
    [[ "$name" == *"$core"* ]]
  elif [[ "$pattern" == \** ]]; then
    core="${pattern#\*}"
    [[ "$name" == *"$core" ]]
  elif [[ "$pattern" == *\* ]]; then
    core="${pattern%\*}"
    [[ "$name" == "$core"* ]]
  else
    [[ "$name" == "$pattern" ]]
  fi
}

has_error=0
if [[ -z "$term" ]]; then
  echo "Erro: informe o parâmetro obrigatório --term <valor>." >&2
  has_error=1
fi

if [[ ! -d "$base_dir" ]]; then
  echo "Erro: --base deve apontar para um diretório válido: $base_dir" >&2
  has_error=1
fi

if (( has_error )); then
  usage
  exit 1
fi

process_path() {
  local path="$1"

  # Ignora linhas vazias
  [[ -z "$path" ]] && return 0

  IFS='/' read -r -a parts <<< "$path"

  local prefix=""
  local i
  for i in "${!parts[@]}"; do
    local part="${parts[$i]}"

    if [[ $i -eq 0 ]]; then
      prefix="$part"
    else
      prefix="$prefix/$part"
    fi

    if matches_term "$part" "$term"; then
      emit_unique "$prefix"
      return 0
    fi
  done
}

# Se há dados via stdin, processa stdin; senão, usa find.
if [[ ! -t 0 ]]; then
  while IFS= read -r line; do
    process_path "$line"
  done
else
  while IFS= read -r dir; do
    process_path "$dir"
  done < <(find "$base_dir" -type d)
fi
