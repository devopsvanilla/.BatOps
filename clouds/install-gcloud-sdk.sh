#!/usr/bin/env bash

set -euo pipefail

# Script para verificar se o Google Cloud SDK está instalado e, se não estiver,
# instalar automaticamente no Ubuntu/Debian.

if command -v gcloud >/dev/null 2>&1; then
  echo "Google Cloud SDK já está instalado. Versão: $(gcloud version | head -n 1)"
  exit 0
fi

echo "Google Cloud SDK não encontrado. Iniciando instalação..."

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "Este script precisa ser executado como root ou com sudo." >&2
  exit 1
fi

if command -v apt-get >/dev/null 2>&1; then
  echo "Instalando dependências do apt..."
  apt-get update
  apt-get install -y ca-certificates gnupg lsb-release curl apt-transport-https

  echo "Adicionando repositório do Google Cloud SDK..."
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null

  echo "Atualizando cache do apt e instalando google-cloud-sdk..."
  apt-get update
  apt-get install -y google-cloud-sdk

  echo "Instalação concluída."
  gcloud version | head -n 1
  exit 0
fi

if command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
  echo "Detecção de yum/dnf não implementada neste script. Por favor, instale o Google Cloud SDK manualmente." >&2
  exit 1
fi

echo "Sistema não suportado para instalação automática do Google Cloud SDK." >&2
exit 1
