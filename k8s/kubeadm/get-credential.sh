#!/usr/bin/env bash

# get-credential.sh
# Retorna URL da API e Token da API do cluster Kubernetes atual.
# Autor: DevOps Vanilla
# Data: 2026-03-06

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SA_NAMESPACE="kube-system"
SA_NAME="api-access"
CRB_NAME="api-access-cluster-admin"
TOKEN_DURATION="24h"
INSECURE_LONG_LIVED="false"

fail() {
  echo -e "${RED}❌ $1${NC}" >&2
  exit 1
}

info() {
  echo -e "${YELLOW}ℹ️  $1${NC}"
}

ok() {
  echo -e "${GREEN}✓ $1${NC}"
}

usage() {
  cat <<EOF
Uso: $(basename "$0") [opções]

Retorna URL da API e token do cluster Kubernetes atual.

Opções:
  --duration <tempo>          Duração do token bound (padrão: ${TOKEN_DURATION})
                              Exemplo: 24h, 720h, 30m
  --namespace <namespace>     Namespace da ServiceAccount (padrão: ${SA_NAMESPACE})
  --serviceaccount <nome>     Nome da ServiceAccount (padrão: ${SA_NAME})
  --insecure-long-lived       Gera token estático legado (sem prazo explícito).
                              NÃO recomendado para produção.
  -h, --help                  Mostra esta ajuda
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --duration)
      [[ $# -lt 2 ]] && fail "Informe um valor para --duration"
      TOKEN_DURATION="$2"
      shift 2
      ;;
    --namespace)
      [[ $# -lt 2 ]] && fail "Informe um valor para --namespace"
      SA_NAMESPACE="$2"
      shift 2
      ;;
    --serviceaccount)
      [[ $# -lt 2 ]] && fail "Informe um valor para --serviceaccount"
      SA_NAME="$2"
      CRB_NAME="${SA_NAME}-cluster-admin"
      shift 2
      ;;
    --insecure-long-lived)
      INSECURE_LONG_LIVED="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Opção inválida: $1 (use --help)"
      ;;
  esac
done

if ! command -v kubectl >/dev/null 2>&1; then
  fail "kubectl não encontrado no PATH."
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  fail "Não foi possível conectar ao cluster. Verifique o kubeconfig/contexto atual."
fi

API_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true)
if [[ -z "${API_URL}" ]]; then
  fail "Não foi possível obter a URL da API do contexto atual."
fi

# Tenta obter token do usuário atual no kubeconfig (quando auth por token é usada).
API_TOKEN=$(kubectl config view --minify -o jsonpath='{.users[0].user.token}' 2>/dev/null || true)

# Se não houver token no kubeconfig (ex.: admin.conf usa cert), gera token via ServiceAccount.
if [[ -z "${API_TOKEN}" ]]; then
  info "Kubeconfig atual não possui token embutido. Gerando token via ServiceAccount..."

  if ! kubectl get sa "${SA_NAME}" -n "${SA_NAMESPACE}" >/dev/null 2>&1; then
    kubectl create sa "${SA_NAME}" -n "${SA_NAMESPACE}" >/dev/null
    ok "ServiceAccount ${SA_NAMESPACE}/${SA_NAME} criada"
  fi

  if ! kubectl get clusterrolebinding "${CRB_NAME}" >/dev/null 2>&1; then
    kubectl create clusterrolebinding "${CRB_NAME}" \
      --clusterrole=cluster-admin \
      --serviceaccount="${SA_NAMESPACE}:${SA_NAME}" >/dev/null
    ok "ClusterRoleBinding ${CRB_NAME} criado"
  fi

  if [[ "${INSECURE_LONG_LIVED}" == "true" ]]; then
    info "Modo inseguro habilitado: tentando gerar token estático legado (sem prazo explícito)."
    info "Use apenas em laboratório. Prefira tokens com --duration em produção."

    STATIC_SECRET_NAME="${SA_NAME}-token"

    # Cria secret legado vinculado à ServiceAccount
    kubectl -n "${SA_NAMESPACE}" apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${STATIC_SECRET_NAME}
  annotations:
    kubernetes.io/service-account.name: ${SA_NAME}
type: kubernetes.io/service-account-token
EOF

    # Aguarda controlador preencher o token no Secret
    for _ in {1..30}; do
      API_TOKEN=$(kubectl -n "${SA_NAMESPACE}" get secret "${STATIC_SECRET_NAME}" -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || true)
      if [[ -n "${API_TOKEN}" ]]; then
        break
      fi
      sleep 1
    done

    if [[ -z "${API_TOKEN}" ]]; then
      fail "Falha ao gerar token estático legado. O cluster pode não permitir esse tipo de token."
    fi
    ok "Token estático legado obtido via Secret ${SA_NAMESPACE}/${STATIC_SECRET_NAME}"
  else
    API_TOKEN=$(kubectl -n "${SA_NAMESPACE}" create token "${SA_NAME}" --duration="${TOKEN_DURATION}" 2>/dev/null || true)
    if [[ -z "${API_TOKEN}" ]]; then
      fail "Falha ao gerar token da API."
    fi
    ok "Token bound gerado com duração: ${TOKEN_DURATION}"
  fi
fi

info "Testando acesso à API com o token gerado..."
if kubectl --token="${API_TOKEN}" --request-timeout=10s get --raw='/version' >/dev/null 2>&1; then
  ok "Acesso validado com sucesso usando o token da API"
else
  fail "Token gerado, mas sem acesso válido à API. Verifique RBAC, contexto atual e conectividade."
fi

echo ""
echo "======================================"
echo "Kubernetes API Credentials"
echo "======================================"
echo "URL da API: ${API_URL}"
echo "Token da API: ${API_TOKEN}"
echo ""
echo "⚠️  Segurança: trate este token como segredo."
echo ""
