#!/usr/bin/env bash
set -euo pipefail

# configure-ado-access.sh
# Configura o acesso Git para contribuir no Azure DevOps (Repos/PRs) a partir
# do terminal, do Visual Studio Code, do Antigravity e do Visual Studio 2022,
# usando o Git Credential Manager (GCM) - a forma recomendada pela Microsoft.
#
# O script SEMPRE cria as configurações de credencial escopadas por host
# (https://dev.azure.com e https://*.visualstudio.com), nunca um
# "credential.helper" global genérico, para não conflitar com o helper do
# GitHub CLI (gh) já configurado neste ambiente. Veja também
# fix-github-ado-conflict.sh.
#
# Uso:
#   ./configure-ado-access.sh [--install-gcm] [--org URL] [--project NOME] [--yes]
#
#   --install-gcm   Instala automaticamente a última versão do Git Credential
#                    Manager (via .deb) sem perguntar antes.
#   --org URL        Organização padrão do Azure DevOps (ex.: https://dev.azure.com/minhaorg)
#   --project NOME   Projeto padrão do Azure DevOps
#   --yes            Modo não interativo: aceita os padrões/valores atuais
#                    sem perguntar (útil em automação/CI).
#
# Se --org/--project não forem informados, o script pergunta interativamente,
# sugerindo o valor já configurado (se houver) como padrão.

INSTALL_GCM=false
ASSUME_YES=false
ORG=""
PROJECT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --install-gcm) INSTALL_GCM=true; shift ;;
    --org) ORG="${2:-}"; shift 2 ;;
    --project) PROJECT="${2:-}"; shift 2 ;;
    --yes) ASSUME_YES=true; shift ;;
    -h|--help)
      echo "Uso: $0 [--install-gcm] [--org URL] [--project NOME] [--yes]"
      exit 0
      ;;
    *)
      echo "⚠️ Argumento desconhecido: $1" >&2
      shift
      ;;
  esac
done

# Pergunta s/n ao usuário. $1=pergunta, $2=padrão ("S" ou "N").
confirm() {
  local question="$1" default="${2:-S}" reply suffix
  if [ "$default" = "N" ]; then suffix="[s/N]"; else suffix="[S/n]"; fi
  if [ "$ASSUME_YES" = true ] || [ ! -t 0 ]; then
    reply="$default"
  else
    read -r -p "$question $suffix " reply || reply="$default"
    reply="${reply:-$default}"
  fi
  [[ "$reply" =~ ^[Ss]$ ]]
}

# Pergunta um valor de texto. $1=pergunta, $2=valor atual/padrão.
ask_value() {
  local question="$1" default="${2:-}" reply
  if [ "$ASSUME_YES" = true ] || [ ! -t 0 ]; then
    printf '%s\n' "$default"
    return
  fi
  read -r -p "$question [${default:-nenhum}]: " reply || reply=""
  printf '%s\n' "${reply:-$default}"
}

if ! command -v git >/dev/null 2>&1; then
  echo "❌ Git não encontrado. Instale o git antes de continuar." >&2
  exit 1
fi

gcm_available() {
  command -v git-credential-manager >/dev/null 2>&1 || command -v git-credential-manager-core >/dev/null 2>&1
}

if gcm_available; then
  echo "✅ Git Credential Manager já disponível: $(command -v git-credential-manager || command -v git-credential-manager-core)"
else
  echo "⚠️ Git Credential Manager (GCM) não encontrado."
  if [ "$INSTALL_GCM" = true ] || confirm "Deseja instalar o Git Credential Manager agora?" "S"; then
    if ! command -v curl >/dev/null 2>&1 || ! command -v dpkg >/dev/null 2>&1; then
      echo "❌ Instalação automática requer 'curl' e 'dpkg' (Debian/Ubuntu). Instale manualmente: https://github.com/git-ecosystem/git-credential-manager/releases" >&2
    else
      echo "⏳ Buscando o instalador .deb mais recente do GCM..."
      ASSET_URL="$(curl -fsSL https://api.github.com/repos/git-ecosystem/git-credential-manager/releases/latest \
        | grep -o '"browser_download_url": *"[^"]*linux_amd64[^"]*\.deb"' \
        | sed -E 's/.*"(https[^"]+)"/\1/' | head -n1)"
      if [ -z "$ASSET_URL" ]; then
        echo "❌ Não foi possível localizar o pacote .deb na última release. Instale manualmente: https://github.com/git-ecosystem/git-credential-manager/releases" >&2
      else
        TMP_DEB="$(mktemp --suffix=.deb)"
        curl -fsSL "$ASSET_URL" -o "$TMP_DEB"
        sudo dpkg -i "$TMP_DEB" || sudo apt-get install -f -y
        rm -f "$TMP_DEB"
        echo "✅ Git Credential Manager instalado."
      fi
    fi
  else
    echo "   Instale manualmente quando quiser: https://github.com/git-ecosystem/git-credential-manager/releases"
  fi
fi

# Define (ou redefine) o helper de credencial apenas para os hosts do Azure
# DevOps, preservando qualquer configuração já existente para o GitHub.
configure_scoped_helper() {
  local url="$1"
  git config --global --unset-all "credential.${url}.helper" 2>/dev/null || true
  git config --global --add "credential.${url}.helper" "manager"
  echo "✅ Configurado credential.${url}.helper = manager"
}

echo "⏳ Configurando helpers de credencial escopados para Azure DevOps..."
configure_scoped_helper "https://dev.azure.com"
configure_scoped_helper "https://*.visualstudio.com"

CURRENT_ORG="$(az devops configure -l 2>/dev/null | awk -F'= *' '/^organization/{print $2}')"
CURRENT_PROJECT="$(az devops configure -l 2>/dev/null | awk -F'= *' '/^project/{print $2}')"

if [ -z "$ORG" ]; then
  ORG="$(ask_value "Organização padrão do Azure DevOps (ex.: https://dev.azure.com/minhaorg)" "$CURRENT_ORG")"
fi
if [ -z "$PROJECT" ]; then
  PROJECT="$(ask_value "Projeto padrão do Azure DevOps" "$CURRENT_PROJECT")"
fi

if [ -n "$ORG" ] || [ -n "$PROJECT" ]; then
  echo "⏳ Atualizando defaults do az devops..."
  ARGS=()
  [ -n "$ORG" ] && ARGS+=("organization=$ORG")
  [ -n "$PROJECT" ] && ARGS+=("project=$PROJECT")
  az devops configure --defaults "${ARGS[@]}"
  echo "✅ Defaults do az devops atualizados."
else
  echo "ℹ️  Nenhum default de organização/projeto configurado (informe via --org/--project ou responda ao prompt)."
fi

echo ""
echo "✅ Configuração concluída. VS Code, Antigravity e Visual Studio 2022 reutilizam o"
echo "   mesmo git config, então o acesso configurado aqui vale para todos eles."
echo ""
echo "Para testar, clone um repositório do seu projeto (irá abrir o navegador"
echo "para autenticação na primeira vez):"
echo "   git clone https://dev.azure.com/SUA_ORG/SEU_PROJETO/_git/SEU_REPO"
