#!/bin/bash

# Verifica se o nome do processo ($0) é o mesmo do arquivo em execução
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Erro: Este script deve ser executado com 'source' ou '.' para configurar o ambiente do seu shell atual."
    echo "Exemplo: source ./setup-gcloud.sh"
    exit 1
fi

# A partir daqui, o script continua apenas se tiver sido 'sourçado'
echo "Script executado via source. Prosseguindo com a configuração..."


# Diretório base
export CLOUDSDK_CONFIG="/home/devopsvanilla/.batops/clouds/credentials/gcloud"
SA_KEY="/home/devopsvanilla/.batops/clouds/credentials/gcloud/morpheuslab-sa.json"

if [ ! -f "$SA_KEY" ]; then
    echo "Erro: Arquivo $SA_KEY não encontrado."
    return 1
fi

# 1. Garante que a configuração existe
if ! gcloud config configurations list --format="value(name)" --quiet | grep -q "^default$"; then
    echo "Criando configuração 'default'..."
    gcloud config configurations create default --quiet
fi

# 2. Extrai o ID do projeto
PROJECT_ID=$(jq -r '.project_id' "$SA_KEY")

# 3. Autentica e configura
gcloud auth activate-service-account --key-file="$SA_KEY" --quiet > /dev/null
gcloud config set project "$PROJECT_ID" --quiet > /dev/null

# 4. Verificação de prontidão
ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
CURRENT_PROJECT=$(gcloud config get-value project --quiet 2>/dev/null)

if [[ "$ACTIVE_ACCOUNT" == *"iam.gserviceaccount.com"* ]] && [[ "$CURRENT_PROJECT" == "$PROJECT_ID" ]]; then
    echo "--------------------------------------------------------"
    echo "Ambiente pronto para uso!"
    echo "Conta: $ACTIVE_ACCOUNT"
    echo "Projeto: $CURRENT_PROJECT"
    echo "--------------------------------------------------------"
else
    echo "Erro: Falha na verificação final do ambiente."
    return 1
fi
