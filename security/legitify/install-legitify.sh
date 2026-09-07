#!/usr/bin/env bash

set -euo pipefail

# Script para instalação e atualização segura do Legitify (Legit-Labs/legitify).
# Fonte oficial: https://github.com/Legit-Labs/legitify
#
# Segurança aplicada:
#   - Não executa "curl | sh": baixa o binário diretamente do release oficial via API do GitHub.
#   - Resolve a versão mais recente (ou instala uma versão específica passada como argumento).
#   - Verifica o checksum SHA-256 do artefato contra o checksums.txt oficial, quando disponível.
#   - Instala em ~/.local/bin (não requer root/sudo).
#
# Uso:
#   ./install-legitify.sh              # instala/atualiza para a versão mais recente
#   ./install-legitify.sh v1.0.11      # instala uma versão específica

REPO="Legit-Labs/legitify"
INSTALL_DIR="${HOME}/.local/bin"
VERSION="${1:-}"

info() { echo "[legitify-install] $*"; }
erro() { echo "[legitify-install] ERRO: $*" >&2; exit 1; }

for cmd in curl tar sha256sum; do
  command -v "$cmd" >/dev/null 2>&1 || erro "Dependência ausente: $cmd. Instale-a e tente novamente."
done

case "$(uname -s)" in
  Linux) SO="linux" ;;
  Darwin) SO="darwin" ;;
  *) erro "Sistema operacional não suportado: $(uname -s)" ;;
esac

case "$(uname -m)" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) erro "Arquitetura não suportada: $(uname -m)" ;;
esac

# Extrai apenas o número da versão da saída "legitify version X.Y.Z commit <hash>".
versao_instalada() {
  legitify version 2>/dev/null | sed -n 's/^legitify version \([0-9][0-9.]*\).*/\1/p'
}

JA_INSTALADO=0
if command -v legitify >/dev/null 2>&1; then
  JA_INSTALADO=1
  VERSAO_ATUAL="$(versao_instalada)"
  info "Legitify já instalado (versão ${VERSAO_ATUAL:-desconhecida}). Verificando atualizações..."
fi

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

VERSION_NUM="${VERSION#v}"

if [ "$JA_INSTALADO" -eq 1 ] && [ "$VERSAO_ATUAL" = "$VERSION_NUM" ]; then
  info "Legitify já está atualizado na versão mais recente (${VERSION}). Nada a fazer."
  exit 0
fi

ASSET="legitify_${VERSION_NUM}_${SO}_${ARCH}.tar.gz"
BASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

info "Baixando ${ASSET} (versão ${VERSION})..."
curl -fsSL --proto '=https' --tlsv1.2 -o "${WORKDIR}/${ASSET}" \
  "${BASE_URL}/${ASSET}" \
  || erro "Falha ao baixar o artefato ${ASSET}. Verifique se a versão/arquitetura existe nos releases do projeto."

info "Verificando checksum..."
if curl -fsSL --proto '=https' --tlsv1.2 -o "${WORKDIR}/SHA256SUMS" \
  "${BASE_URL}/legitify_${VERSION_NUM}_SHA256SUMS" 2>/dev/null; then
  EXPECTED="$(grep " ${ASSET}\$" "${WORKDIR}/SHA256SUMS" | awk '{print $1}')"
  ACTUAL="$(sha256sum "${WORKDIR}/${ASSET}" | awk '{print $1}')"
  if [ -z "$EXPECTED" ]; then
    info "AVISO: checksum do artefato não encontrado no arquivo SHA256SUMS. Prosseguindo sem verificação."
  elif [ "$EXPECTED" != "$ACTUAL" ]; then
    erro "Checksum inválido para ${ASSET}! Esperado ${EXPECTED}, obtido ${ACTUAL}."
  else
    info "Checksum verificado com sucesso."
  fi
else
  info "AVISO: não foi possível baixar SHA256SUMS. Prosseguindo sem verificação de integridade."
fi

info "Extraindo artefato..."
tar -xzf "${WORKDIR}/${ASSET}" -C "$WORKDIR"

mkdir -p "$INSTALL_DIR"
install -m 0755 "${WORKDIR}/legitify" "${INSTALL_DIR}/legitify"

info "Legitify ${VERSION} instalado em ${INSTALL_DIR}/legitify"

case ":$PATH:" in
  *":${INSTALL_DIR}:"*) ;;
  *) info "AVISO: ${INSTALL_DIR} não está no seu PATH. Adicione a linha abaixo ao seu ~/.bashrc ou ~/.zshrc:"
     info "  export PATH=\"\${HOME}/.local/bin:\${PATH}\"" ;;
esac

"${INSTALL_DIR}/legitify" version || true
