#!/usr/bin/env bash

set -euo pipefail

# Script de auditoria de segurança da organização/repositórios GitHub usando o Legitify
# (https://github.com/Legit-Labs/legitify), com geração de relatório em PDF.
#
# Modos de uso:
#   Interativo (padrão): faz perguntas para coletar token, organização(ões),
#     repositórios, namespaces e diretório de saída.
#       ./audit-github.sh
#
#   Não-interativo (para cron/CI): utiliza variáveis de ambiente, sem prompts.
#       GITHUB_TOKEN=ghp_xxx GITHUB_ORG=minha-org ./audit-github.sh --non-interactive
#
# Variáveis de ambiente suportadas (usadas como valores padrão dos prompts,
# ou obrigatórias em modo --non-interactive):
#   GITHUB_TOKEN            PAT do GitHub com escopos: admin:org, read:enterprise,
#                           admin:org_hook, read:org, repo, read:repo_hook
#   GITHUB_ORG              (opcional) Organização(ões) GitHub, separadas por vírgula
#   GITHUB_REPO             (opcional) Repositório(s) específicos "org/repo", separados por vírgula
#   LEGITIFY_INCLUDE_PERSONAL_REPOS (opcional) 1/true para incluir também os repositórios
#                           pessoais (fora de organizações) do usuário dono do PAT
#   LEGITIFY_NAMESPACES     (opcional) organization,actions,member,repository,runner_group
#   LEGITIFY_IGNORE_POLICIES_PATH (opcional) caminho de arquivo com políticas a ignorar
#   LEGITIFY_OUTPUT_DIR     (opcional) diretório de saída dos relatórios (padrão: ./reports)
#
# Se nem GITHUB_ORG nem GITHUB_REPO forem informados, o Legitify analisa por padrão
# TODOS os recursos (organizações, repositórios, membros, actions) que o token enxergar.
#
# Ordem de prioridade para o token e demais valores: (1) variável já exportada
# no ambiente (ex.: injetada pelo CI) > (2) arquivo .env no mesmo diretório do
# script (recomendado para uso local, evita expor o token no histórico do bash)
# > (3) token da GH CLI, apenas como sugestão (escopos limitados) > (4) prompt manual.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NON_INTERACTIVE=0

for arg in "$@"; do
  case "$arg" in
    --non-interactive) NON_INTERACTIVE=1 ;;
    -h|--help)
      grep -E '^#( |$)' "$0" | sed 's/^#//'
      exit 0
      ;;
    *) echo "Argumento desconhecido: $arg" >&2; exit 1 ;;
  esac
done

info() { echo "[legitify-audit] $*"; }
erro() { echo "[legitify-audit] ERRO: $*" >&2; exit 1; }

# --- 1. Garante que o legitify está instalado e atualizado ---------------------
if ! command -v legitify >/dev/null 2>&1; then
  info "Legitify não encontrado. Instalando..."
  "${SCRIPT_DIR}/install-legitify.sh"
  export PATH="${HOME}/.local/bin:${PATH}"
fi
command -v legitify >/dev/null 2>&1 || erro "Legitify não pôde ser instalado/localizado no PATH."

# --- 2. Carrega valores padrão do arquivo .env (se existir) ---------------------
# Preenche apenas variáveis ainda não definidas no ambiente (uma variável já
# exportada explicitamente pelo usuário/CI sempre tem prioridade sobre o .env).
# Isso evita depender de "export GITHUB_TOKEN=..." manual no shell (que fica
# registrado no histórico do bash) — o token pode ficar apenas no .env
# (arquivo local, ignorado pelo git, com permissão restrita via chmod 600).
carregar_defaults_do_env() {
  local env_file="${SCRIPT_DIR}/.env"
  [ -f "$env_file" ] || return 0
  local linha chave valor
  while IFS= read -r linha || [ -n "$linha" ]; do
    [[ "$linha" =~ ^[[:space:]]*(#.*)?$ ]] && continue
    chave="${linha%%=*}"
    valor="${linha#*=}"
    chave="${chave%"${chave##*[![:space:]]}"}"
    chave="${chave#"${chave%%[![:space:]]*}"}"
    [[ "$chave" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    valor="${valor%\"}"; valor="${valor#\"}"
    valor="${valor%\'}"; valor="${valor#\'}"
    if [ -z "${!chave:-}" ] && [ -n "$valor" ]; then
      printf -v "$chave" '%s' "$valor"
      export "${chave?}"
    fi
  done < "$env_file"
}
carregar_defaults_do_env

# --- 3. Coleta de parâmetros (prompts ou variáveis de ambiente) ----------------
prompt() {
  # prompt <variavel> <mensagem> <default> <secreto:0|1>
  local __var="$1" __msg="$2" __default="${3:-}" __secret="${4:-0}"
  local __current="${!__var:-}"
  if [ "$NON_INTERACTIVE" -eq 1 ]; then
    [ -n "$__current" ] || [ -n "$__default" ] || erro "Variável obrigatória não definida: ${__var}"
    printf -v "$__var" '%s' "${__current:-$__default}"
    return
  fi
  local __ans
  if [ "$__secret" -eq 1 ]; then
    read -rsp "${__msg}${__current:+ [já definido no .env, ENTER para manter]}: " __ans
    echo
  else
    read -rp "${__msg}${__default:+ [${__default}]}: " __ans
  fi
  __ans="${__ans:-${__current:-$__default}}"
  [ -n "$__ans" ] || erro "Valor obrigatório não informado para ${__var}."
  printf -v "$__var" '%s' "$__ans"
}

# Busca, via API do GitHub, os repositórios pessoais (fora de organizações) do
# usuário dono do PAT informado, retornando uma lista "dono/repo" separada por vírgula.
descobrir_repositorios_pessoais() {
  local page=1 resposta ids repos=""
  while :; do
    resposta="$(curl -fsSL --proto '=https' --tlsv1.2 \
      -H "Authorization: token ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/user/repos?affiliation=owner&per_page=100&page=${page}" 2>/dev/null)"
    [ -n "$resposta" ] && [ "$resposta" != "[]" ] || break
    if command -v jq >/dev/null 2>&1; then
      ids="$(echo "$resposta" | jq -r '.[] | select(.archived == false) | .full_name')"
    else
      ids="$(echo "$resposta" | grep -o '"full_name": *"[^"]*"' | sed -E 's/.*"([^"]+)"$/\1/')"
    fi
    [ -n "$ids" ] || break
    repos="${repos}${repos:+,}$(echo "$ids" | paste -sd, -)"
    [ "$(echo "$ids" | wc -l)" -lt 100 ] && break
    page=$((page + 1))
  done
  echo "$repos"
}

# Normaliza a lista de organizações informada: aceita apenas o slug, removendo
# prefixos de URL (ex.: "https://github.com/minha-org" -> "minha-org") caso o
# usuário cole o link da organização por engano.
sanitizar_orgs() {
  local entrada="$1" saida="" parte partes
  IFS=',' read -ra partes <<< "$entrada"
  for parte in "${partes[@]}"; do
    parte="$(echo "$parte" | xargs)"
    parte="${parte#https://github.com/}"
    parte="${parte#http://github.com/}"
    parte="${parte%/}"
    [ -n "$parte" ] && saida="${saida:+${saida},}${parte}"
  done
  echo "$saida"
}

: "${GITHUB_TOKEN:=${SCM_TOKEN:-}}"

# A GH CLI (gh) tem seu próprio token, mas normalmente sem os escopos admin:org,
# read:enterprise, admin:org_hook e read:repo_hook exigidos pelo Legitify para uma
# análise completa. Só sugerimos o token da gh se não houver token no .env nem
# em variável já exportada — é a fonte de menor prioridade.
if [ "$NON_INTERACTIVE" -eq 0 ] && [ -z "$GITHUB_TOKEN" ] && command -v gh >/dev/null 2>&1; then
  if GH_CLI_TOKEN="$(gh auth token 2>/dev/null)" && [ -n "$GH_CLI_TOKEN" ]; then
    info "GH CLI autenticada detectada. Seu token não costuma ter os escopos" \
      "admin:org/read:enterprise/admin:org_hook/read:repo_hook necessários para a" \
      "análise completa (organização, membros, actions) — apenas repositórios."
    GITHUB_TOKEN="$GH_CLI_TOKEN"
  fi
fi

prompt GITHUB_TOKEN "Informe o GitHub Personal Access Token - PAT (recomendado, com escopos: admin:org, read:enterprise, admin:org_hook, read:org, repo, read:repo_hook)" "" 1

if [ "$NON_INTERACTIVE" -eq 0 ]; then
  read -rp "Organização(ões) GitHub a auditar, separadas por vírgula (opcional — deixe em branco para auditar somente repositórios pessoais, ou se quiser que o Legitify analise tudo que o token enxergar) [${GITHUB_ORG:-}]: " ORG_INPUT
  GITHUB_ORG="${ORG_INPUT:-${GITHUB_ORG:-}}"
else
  : "${GITHUB_ORG:=}"
fi
GITHUB_ORG="$(sanitizar_orgs "${GITHUB_ORG:-}")"

if [ "$NON_INTERACTIVE" -eq 0 ]; then
  read -rp "Repositório(s) específicos 'org/repo' (opcional, separados por vírgula) [${GITHUB_REPO:-}]: " GITHUB_REPO_INPUT
  GITHUB_REPO="${GITHUB_REPO_INPUT:-${GITHUB_REPO:-}}"

  read -rp "Incluir também os repositórios pessoais (fora de organizações) do usuário dono do PAT? [s/N]: " INCLUDE_PERSONAL_INPUT
  case "${INCLUDE_PERSONAL_INPUT,,}" in
    s|sim|y|yes) LEGITIFY_INCLUDE_PERSONAL_REPOS=1 ;;
    *) : "${LEGITIFY_INCLUDE_PERSONAL_REPOS:=0}" ;;
  esac

  read -rp "Namespaces a analisar (organization,actions,member,repository,runner_group) [todos]: " NS_INPUT
  LEGITIFY_NAMESPACES="${NS_INPUT:-${LEGITIFY_NAMESPACES:-}}"

  read -rp "Caminho de arquivo com políticas a ignorar (opcional) [${LEGITIFY_IGNORE_POLICIES_PATH:-}]: " IGNORE_INPUT
  LEGITIFY_IGNORE_POLICIES_PATH="${IGNORE_INPUT:-${LEGITIFY_IGNORE_POLICIES_PATH:-}}"

  read -rp "Diretório de saída dos relatórios [${LEGITIFY_OUTPUT_DIR:-./reports}]: " OUTDIR_INPUT
  LEGITIFY_OUTPUT_DIR="${OUTDIR_INPUT:-${LEGITIFY_OUTPUT_DIR:-./reports}}"
else
  : "${GITHUB_REPO:=}"
  : "${LEGITIFY_INCLUDE_PERSONAL_REPOS:=0}"
  : "${LEGITIFY_NAMESPACES:=}"
  : "${LEGITIFY_IGNORE_POLICIES_PATH:=}"
  : "${LEGITIFY_OUTPUT_DIR:=./reports}"
fi

if [ "${LEGITIFY_INCLUDE_PERSONAL_REPOS:-0}" = "1" ] || [ "${LEGITIFY_INCLUDE_PERSONAL_REPOS:-}" = "true" ]; then
  info "Consultando repositórios pessoais do usuário dono do PAT..."
  PERSONAL_REPOS="$(descobrir_repositorios_pessoais)"
  if [ -n "$PERSONAL_REPOS" ]; then
    GITHUB_REPO="${GITHUB_REPO:+${GITHUB_REPO},}${PERSONAL_REPOS}"
    info "Repositórios pessoais incluídos: $(echo "$PERSONAL_REPOS" | tr ',' '\n' | wc -l)"
  else
    info "Nenhum repositório pessoal encontrado (ou a API não respondeu)."
  fi
fi

[ -n "$GITHUB_ORG" ] || [ -n "$GITHUB_REPO" ] || info "AVISO: nenhuma organização/repositório informado — o Legitify analisará TODOS os recursos que o token enxergar."

export SCM_TOKEN="$GITHUB_TOKEN"

# --- 4. Prepara diretório de saída e nomes de arquivo -----------------------------
mkdir -p "$LEGITIFY_OUTPUT_DIR"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ORG_SLUG="$(echo "${GITHUB_ORG:-pessoal}" | tr ',/ ' '___')"
BASENAME="legitify-report-${ORG_SLUG}-${TIMESTAMP}"
TXT_FILE="${LEGITIFY_OUTPUT_DIR}/${BASENAME}.txt"
MD_FILE="${LEGITIFY_OUTPUT_DIR}/${BASENAME}.md"
PDF_FILE="${LEGITIFY_OUTPUT_DIR}/${BASENAME}.pdf"
ERR_FILE="${LEGITIFY_OUTPUT_DIR}/${BASENAME}.error.log"
JSON_FILES=()

# --- 5. Executa a análise --------------------------------------------------------
# O Legitify não permite combinar --org e --repo na mesma chamada ("cannot use
# --org & --repo options together"), então cada escopo é analisado separadamente
# e os relatórios em texto são combinados no arquivo final.
: > "$TXT_FILE"
ESCOPOS_EXECUTADOS=0

executar_escopo() {
  # executar_escopo <rotulo> <argumentos de escopo do legitify...>
  local rotulo="$1"; shift
  local args=(analyze --color=none "$@")
  [ -n "$LEGITIFY_NAMESPACES" ] && args+=(--namespace "$LEGITIFY_NAMESPACES")
  [ -n "$LEGITIFY_IGNORE_POLICIES_PATH" ] && args+=(--ignore-policies-path "$LEGITIFY_IGNORE_POLICIES_PATH")

  local txt_parcial="${LEGITIFY_OUTPUT_DIR}/${BASENAME}.${rotulo}.txt"
  local json_parcial="${LEGITIFY_OUTPUT_DIR}/${BASENAME}.${rotulo}.json"
  local err_parcial="${ERR_FILE}.${rotulo}"

  info "Executando análise Legitify — escopo: ${rotulo}"
  set +e
  legitify "${args[@]}" --output-file "$txt_parcial" --error-file "$err_parcial"
  local rc=$?
  legitify "${args[@]}" --output-format json --output-file "$json_parcial" --error-file "${err_parcial}.json"
  set -e

  if [ "$rc" -ge 2 ] || grep -qm1 '^Error:' "$txt_parcial" 2>/dev/null; then
    erro "Falha ao executar o legitify no escopo '${rotulo}'. Verifique ${err_parcial} e ${txt_parcial} para detalhes."
  fi

  {
    echo "===== Escopo: ${rotulo} ====="
    echo
    cat "$txt_parcial"
    echo
  } >> "$TXT_FILE"
  JSON_FILES+=("$json_parcial")
  ESCOPOS_EXECUTADOS=1
}

[ -n "$GITHUB_ORG" ] && executar_escopo "organizacao" --org "$GITHUB_ORG"
[ -n "$GITHUB_REPO" ] && executar_escopo "repositorios" --repo "$GITHUB_REPO"
[ "$ESCOPOS_EXECUTADOS" -eq 0 ] && executar_escopo "tudo"

info "Legitify concluído. Relatórios parciais combinados em ${TXT_FILE}."

# --- 6. Gera o PDF a partir do relatório em texto -------------------------------
{
  echo "% Relatório de Auditoria Legitify"
  echo "% Organização(ões): ${GITHUB_ORG}"
  echo "% Gerado em: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo
  echo '```'
  cat "$TXT_FILE"
  echo '```'
} > "$MD_FILE"

PDF_ENGINE=""
for engine in wkhtmltopdf weasyprint xelatex pdflatex; do
  command -v "$engine" >/dev/null 2>&1 && { PDF_ENGINE="$engine"; break; }
done

if command -v pandoc >/dev/null 2>&1 && [ -n "$PDF_ENGINE" ]; then
  info "Gerando PDF com pandoc (engine: ${PDF_ENGINE})..."
  pandoc "$MD_FILE" -o "$PDF_FILE" --pdf-engine="$PDF_ENGINE" \
    -V geometry:margin=1.5cm -V mainfont="DejaVu Sans Mono" --highlight-style=tango \
    || info "AVISO: falha ao gerar PDF com pandoc. Relatórios em texto/JSON permanecem disponíveis."
else
  info "AVISO: pandoc e/ou um mecanismo de PDF (wkhtmltopdf/weasyprint/xelatex/pdflatex) não encontrados."
  info "Instale, por exemplo: sudo apt-get install -y pandoc wkhtmltopdf"
  info "O relatório em texto e JSON foram salvos normalmente."
fi

info "Relatórios gerados em: ${LEGITIFY_OUTPUT_DIR}"
info "  - Texto (combinado): ${TXT_FILE}"
for jf in "${JSON_FILES[@]}"; do
  info "  - JSON: ${jf}"
done
[ -f "$PDF_FILE" ] && info "  - PDF:   ${PDF_FILE}"

exit 0
