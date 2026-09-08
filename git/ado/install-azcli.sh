#!/usr/bin/env bash
set -euo pipefail

# install-azcli.sh
# Instala (ou valida) o Azure CLI (az) e a extensão "azure-devops",
# necessários para trabalhar com repositórios, Pull Requests, Boards e
# Pipelines do Azure DevOps a partir do terminal.
#
# Uso:
#   ./install-azcli.sh [--force-native] [--yes]
#
#   --force-native  Força a instalação de uma cópia nativa do az CLI no
#                   Linux, mesmo que ele já esteja disponível via
#                   interoperabilidade do WSL com o Windows.
#   --yes           Modo não interativo: aceita os valores padrão de cada
#                   confirmação sem perguntar (útil em automação/CI).
#
# Itens já configurados (az CLI e extensão azure-devops já instalados) são
# sempre confirmados com o usuário antes de qualquer alteração.

FORCE_NATIVE=false
ASSUME_YES=false
for arg in "$@"; do
  case "$arg" in
    --force-native) FORCE_NATIVE=true ;;
    --yes) ASSUME_YES=true ;;
    -h|--help)
      echo "Uso: $0 [--force-native] [--yes]"
      echo "  --force-native  Força a instalação nativa do az CLI no Linux"
      echo "                  mesmo que já exista via interop do WSL/Windows."
      echo "  --yes           Modo não interativo (aceita os padrões)."
      exit 0
      ;;
    *)
      echo "⚠️ Argumento desconhecido: $arg" >&2
      ;;
  esac
done

# Pergunta s/n ao usuário. $1=pergunta, $2=padrão ("S" ou "N").
# Em modo não interativo (sem TTY ou --yes) responde o padrão automaticamente.
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

is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null
}

install_linux_native() {
  echo "⏳ Instalando Azure CLI nativamente..."
  if command -v apt-get >/dev/null 2>&1; then
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y https://packages.microsoft.com/config/rhel/9/packages-microsoft-prod.rpm
    sudo dnf install -y azure-cli
  elif command -v yum >/dev/null 2>&1; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo sh -c 'printf "[azure-cli]\nname=Azure CLI\nbaseurl=https://packages.microsoft.com/yumrepos/azure-cli\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n" > /etc/yum.repos.d/azure-cli.repo'
    sudo yum install -y azure-cli
  else
    echo "❌ Gerenciador de pacotes não suportado para instalação automática do az CLI." >&2
    exit 1
  fi
  echo "✅ Azure CLI instalado nativamente."
}

CURRENT_AZ_PATH=""
if command -v az >/dev/null 2>&1; then
  CURRENT_AZ_PATH="$(command -v az)"
fi

if [ -n "$CURRENT_AZ_PATH" ]; then
  echo "✅ Azure CLI já disponível em: $CURRENT_AZ_PATH"
  az version --output table 2>/dev/null || az --version
  if is_wsl && [[ "$CURRENT_AZ_PATH" == /mnt/* ]]; then
    echo "ℹ️  Detectado WSL usando o Azure CLI do Windows via interoperabilidade."
  fi

  if [ "$FORCE_NATIVE" = true ]; then
    echo "⚠️ Instalação nativa forçada solicitada (--force-native)."
    install_linux_native
  elif confirm "Deseja instalar/reinstalar uma cópia nativa do az CLI no Linux mesmo assim?" "N"; then
    install_linux_native
  else
    echo "↪️  Mantendo a instalação atual do az CLI, sem alterações."
  fi
else
  install_linux_native
fi

echo "⏳ Verificando extensão 'azure-devops'..."
if az extension list --output tsv --query "[?name=='azure-devops'].name" 2>/dev/null | grep -q azure-devops; then
  echo "✅ Extensão 'azure-devops' já instalada."
  if confirm "Deseja atualizar a extensão 'azure-devops' para a última versão agora?" "S"; then
    az extension update --name azure-devops --only-show-errors || true
    echo "✅ Extensão atualizada."
  else
    echo "↪️  Mantendo a versão atual da extensão."
  fi
else
  az extension add --name azure-devops --only-show-errors
  echo "✅ Extensão 'azure-devops' instalada."
fi

echo ""
echo "✅ Pronto! Próximos passos (são 2 comandos separados, execute um de cada vez):"
echo "   1) Autentique-se:"
echo "      az login"
echo "   2) Configure os defaults do Azure DevOps (--defaults é opção do 'az devops configure', não do 'az login'):"
echo "      az devops configure --defaults organization=https://dev.azure.com/SUA_ORG project=SEU_PROJETO"
echo "   3) Rode ./configure-ado-access.sh para preparar o acesso Git (terminal, VS Code, Antigravity e Visual Studio 2022)."
