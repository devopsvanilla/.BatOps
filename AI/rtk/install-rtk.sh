#!/usr/bin/env bash

set -euo pipefail

# Script para instalação segura e atualizada do RTK CLI (Rust Token Killer).
# Fonte oficial: https://github.com/rtk-ai/rtk
#
# Segurança aplicada:
#   - Não executa "curl | sh": baixa o binário diretamente do release oficial.
#   - Resolve a versão mais recente via API do GitHub (sempre atualizado).
#   - Verifica o checksum SHA-256 do artefato contra o checksums.txt oficial.
#   - Instala em ~/.local/bin (não requer root/sudo).
#
# Uso:
#   ./install-rtk.sh              # instala a versão mais recente
#   ./install-rtk.sh v0.48.0      # instala uma versão específica

REPO="rtk-ai/rtk"
INSTALL_DIR="${HOME}/.local/bin"
VERSION="${1:-}"

info() { echo "[rtk-install] $*"; }
erro() { echo "[rtk-install] ERRO: $*" >&2; exit 1; }

# Dependências necessárias
for cmd in curl tar sha256sum; do
  command -v "$cmd" >/dev/null 2>&1 || erro "Dependência ausente: $cmd. Instale-a e tente novamente."
done

# Se já estiver instalado e nenhuma versão específica foi pedida, atualiza apenas se houver versão nova.
if command -v rtk >/dev/null 2>&1 && [ -z "$VERSION" ]; then
  VERSAO_ATUAL="$(rtk --version 2>/dev/null | awk '{print $2}' || echo 'desconhecida')"
  info "RTK já instalado (versão ${VERSAO_ATUAL}). Verificando atualizações..."
fi

# Resolve a versão mais recente via API oficial do GitHub.
# Nota: o JSON é salvo em arquivo temporário antes do parsing. Fazer pipe direto
# do curl para o grep faz o grep sair após o primeiro match (SIGPIPE), e o curl
# aborta com o erro 23 ("Failure writing output to destination").
if [ -z "$VERSION" ]; then
  info "Consultando a versão mais recente no GitHub..."
  API_JSON="$(mktemp)"
  trap 'rm -f "$API_JSON"' EXIT
  curl -fsSL --proto '=https' --tlsv1.2 \
    "https://api.github.com/repos/${REPO}/releases/latest" -o "$API_JSON" \
    || erro "Falha ao consultar a API do GitHub."
  VERSION="$(grep -m1 '"tag_name"' "$API_JSON" | cut -d'"' -f4)"
  rm -f "$API_JSON"
  trap - EXIT
  [ -n "$VERSION" ] || erro "Não foi possível determinar a versão mais recente."
fi

# Se já está na versão alvo, sai sem reinstalar.
if command -v rtk >/dev/null 2>&1; then
  VERSAO_ATUAL="$(rtk --version 2>/dev/null | awk '{print $2}' || echo '')"
  if [ "v${VERSAO_ATUAL}" = "$VERSION" ]; then
    info "RTK já está na versão mais recente (${VERSION}). Nada a fazer."
    exit 0
  fi
fi

# Detecta SO e arquitetura para escolher o artefato correto.
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Linux)
    case "$ARCH" in
      x86_64)  ALVO="x86_64-unknown-linux-musl" ;;  # musl: binário estático, mais portátil
      aarch64) ALVO="aarch64-unknown-linux-gnu" ;;
      *) erro "Arquitetura Linux não suportada: $ARCH" ;;
    esac
    EXT="tar.gz"
    ;;
  Darwin)
    case "$ARCH" in
      x86_64) ALVO="x86_64-apple-darwin" ;;
      arm64)  ALVO="aarch64-apple-darwin" ;;
      *) erro "Arquitetura macOS não suportada: $ARCH" ;;
    esac
    EXT="tar.gz"
    ;;
  *) erro "Sistema operacional não suportado por este script: $OS" ;;
esac

ARTEFATO="rtk-${ALVO}.${EXT}"
BASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"

info "Versão: ${VERSION} | Alvo: ${ALVO}"

# Diretório temporário com limpeza garantida.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Download do artefato e do checksum oficial.
info "Baixando ${ARTEFATO}..."
curl -fsSL --proto '=https' --tlsv1.2 "${BASE_URL}/${ARTEFATO}" -o "${TMP_DIR}/${ARTEFATO}" \
  || erro "Falha no download de ${ARTEFATO}. Verifique se a versão ${VERSION} possui este artefato."

info "Baixando checksums.txt oficial..."
curl -fsSL --proto '=https' --tlsv1.2 "${BASE_URL}/checksums.txt" -o "${TMP_DIR}/checksums.txt" \
  || erro "Falha no download do checksums.txt."

# Verificação de integridade SHA-256 (somente a linha do artefato baixado).
info "Verificando integridade SHA-256..."
grep "  ${ARTEFATO}\$" "${TMP_DIR}/checksums.txt" > "${TMP_DIR}/checksum.txt" \
  || erro "Checksum do artefato ${ARTEFATO} não encontrado no checksums.txt."
( cd "$TMP_DIR" && sha256sum -c checksum.txt ) \
  || erro "Falha na verificação do checksum. O download pode ter sido corrompido ou adulterado. Abortando."

# Extração e instalação.
info "Extraindo pacote..."
tar -xzf "${TMP_DIR}/${ARTEFATO}" -C "$TMP_DIR"

BINARIO="$(find "$TMP_DIR" -type f -name rtk -not -path '*/\.*' | head -n 1)"
[ -n "$BINARIO" ] || erro "Binário 'rtk' não encontrado dentro do pacote ${ARTEFATO}."

mkdir -p "$INSTALL_DIR"
install -m 0755 "$BINARIO" "${INSTALL_DIR}/rtk"
info "Instalado em ${INSTALL_DIR}/rtk"

# Verificação pós-instalação: garante que é o RTK correto (evita colisão com o 'rtk' do crates.io).
if "${INSTALL_DIR}/rtk" --version >/dev/null 2>&1; then
  info "Instalação concluída: $("${INSTALL_DIR}/rtk" --version)"
else
  erro "O binário foi instalado, mas falhou ao executar 'rtk --version'."
fi

# Garante que o diretório de instalação está no PATH.
case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *)
    info "ATENÇÃO: ${INSTALL_DIR} não está no seu PATH."
    info "Adicione com: echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
    ;;
esac

info "Próximos passos: execute 'rtk init -g' para integrar ao seu agente de IA e 'rtk gain' para ver o painel de economia."
