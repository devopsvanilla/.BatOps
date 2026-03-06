#!/bin/bash

# Script para instalar e validar Flannel CNI Plugin
# - Baixa e aplica o manifesto oficial
# - Aguarda pods ficarem prontos
# - Valida deployment completo
# - Verifica nodes ficarem Ready
# Autor: DevOps Vanilla
# Data: 2026-03-06

set -e

echo "======================================"
echo "Flannel CNI Plugin Installation"
echo "======================================"
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verifica se kubectl está disponível
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl não encontrado${NC}"
    echo "   Execute primeiro: bash ./setup-kubectl.sh"
    exit 1
fi

# Verifica se consegue conectar ao cluster
echo "Verificando conexão com o cluster..."
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}❌ Não foi possível conectar ao cluster${NC}"
    echo "   Verifique se o cluster está inicializado e kubectl configurado"
    exit 1
fi

echo -e "${GREEN}✓ Conectado ao cluster${NC}"
echo ""

# URL do manifesto Flannel
FLANNEL_URL="https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"

echo "======================================"
echo "[1/5] Baixando manifesto do Flannel..."
echo "======================================"

# Baixar manifesto para verificar antes
TEMP_MANIFEST=$(mktemp)
if curl -sSL "$FLANNEL_URL" -o "$TEMP_MANIFEST"; then
    echo -e "${GREEN}✓ Manifesto baixado com sucesso${NC}"
    
    # Mostrar versão se disponível
    VERSION=$(grep -oP 'image:.*flannel.*:v\K[0-9.]+' "$TEMP_MANIFEST" | head -1 || echo "latest")
    echo "  Versão detectada: v$VERSION"
else
    echo -e "${RED}❌ Erro ao baixar manifesto${NC}"
    exit 1
fi

echo ""
echo "======================================"
echo "[2/5] Verificando instalações prévias..."
echo "======================================"

# Verificar se Flannel já está instalado
if kubectl get ns kube-flannel &>/dev/null; then
    echo -e "${YELLOW}⚠️  Flannel já está instalado${NC}"
    echo ""
    read -p "Deseja reinstalar? (s/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Instalação cancelada"
        rm -f "$TEMP_MANIFEST"
        exit 0
    fi
    
    echo "Removendo instalação anterior..."
    kubectl delete -f "$FLANNEL_URL" --ignore-not-found=true 2>/dev/null || true
    sleep 5
    echo -e "${GREEN}✓ Instalação anterior removida${NC}"
fi

echo ""
echo "======================================"
echo "[3/5] Aplicando manifesto do Flannel..."
echo "======================================"

if kubectl apply -f "$TEMP_MANIFEST"; then
    echo -e "${GREEN}✓ Manifesto aplicado com sucesso${NC}"
else
    echo -e "${RED}❌ Erro ao aplicar manifesto${NC}"
    rm -f "$TEMP_MANIFEST"
    exit 1
fi

# Limpar arquivo temporário
rm -f "$TEMP_MANIFEST"

echo ""
echo "======================================"
echo "[4/5] Aguardando pods do Flannel..."
echo "======================================"
echo "Este processo pode levar até 2 minutos..."
echo ""

# Aguardar namespace ser criado
echo -n "Aguardando namespace kube-flannel..."
for i in {1..30}; do
    if kubectl get ns kube-flannel &>/dev/null; then
        echo -e " ${GREEN}OK${NC}"
        break
    fi
    sleep 2
    echo -n "."
done

# Aguardar DaemonSet ser criado
sleep 3

# Contar quantos nodes existem
TOTAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
echo "Nodes no cluster: $TOTAL_NODES"
echo ""

# Aguardar pods do Flannel ficarem prontos
MAX_WAIT=120  # 2 minutos
WAIT_COUNT=0

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    # Pegar status dos pods
    READY_PODS=$(kubectl get pods -n kube-flannel --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    TOTAL_PODS=$(kubectl get pods -n kube-flannel --no-headers 2>/dev/null | wc -l || echo "0")
    
    # Mostrar progresso
    echo -ne "\rPods Flannel: $READY_PODS/$TOTAL_PODS prontos (esperando $TOTAL_NODES)..."
    
    # Verificar se todos os pods estão rodando
    if [ "$READY_PODS" -ge "$TOTAL_NODES" ] && [ "$READY_PODS" -eq "$TOTAL_PODS" ]; then
        echo -e " ${GREEN}COMPLETO${NC}"
        break
    fi
    
    sleep 3
    WAIT_COUNT=$((WAIT_COUNT + 3))
done

echo ""

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    echo -e "${YELLOW}⚠️  Timeout aguardando pods. Status atual:${NC}"
    kubectl get pods -n kube-flannel
    echo ""
    echo "Execute para monitorar: kubectl get pods -n kube-flannel -w"
else
    echo -e "${GREEN}✓ Todos os pods do Flannel estão rodando${NC}"
fi

echo ""
echo "======================================"
echo "[5/5] Validando instalação..."
echo "======================================"

# Mostrar pods do Flannel
echo ""
echo "Pods do Flannel:"
kubectl get pods -n kube-flannel -o wide

echo ""
echo "Aguardando nodes ficarem Ready (até 30 segundos)..."

# Aguardar nodes ficarem Ready
for i in {1..10}; do
    NOT_READY=$(kubectl get nodes --no-headers | grep -c "NotReady" || echo "0")
    
    if [ "$NOT_READY" -eq 0 ]; then
        echo -e "${GREEN}✓ Todos os nodes estão Ready${NC}"
        break
    fi
    
    echo -n "."
    sleep 3
done

echo ""
echo "Status dos nodes:"
kubectl get nodes

echo ""
echo "======================================"
echo "✓ Instalação do Flannel concluída!"
echo "======================================"
echo ""

# Validação final
ALL_RUNNING=$(kubectl get pods -n kube-flannel --no-headers 2>/dev/null | grep -c "Running" || echo "0")
NOT_READY=$(kubectl get nodes --no-headers | grep -c "NotReady" || echo "0")

if [ "$ALL_RUNNING" -ge "$TOTAL_NODES" ] && [ "$NOT_READY" -eq 0 ]; then
    echo -e "${GREEN}🎉 SUCESSO! Flannel está funcionando corretamente${NC}"
    echo ""
    echo "✅ Verificações:"
    echo "   • Pods do Flannel: $ALL_RUNNING/$TOTAL_NODES rodando"
    echo "   • Nodes Ready: $TOTAL_NODES/$TOTAL_NODES"
    echo ""
    echo "📋 Próximos passos:"
    echo "   1. Teste criar um deployment:"
    echo "      kubectl create deployment nginx --image=nginx --replicas=2"
    echo ""
    echo "   2. Verifique a rede:"
    echo "      kubectl get pods -o wide"
    echo ""
    echo "   3. Teste comunicação entre pods:"
    echo "      kubectl run test --image=busybox --rm -it -- wget -qO- <POD_IP>"
else
    echo -e "${YELLOW}⚠️  ATENÇÃO: Instalação pode estar incompleta${NC}"
    echo ""
    echo "Status atual:"
    echo "   • Pods Flannel rodando: $ALL_RUNNING/$TOTAL_NODES"
    echo "   • Nodes NotReady: $NOT_READY"
    echo ""
    echo "Comandos para diagnóstico:"
    echo "   kubectl get pods -n kube-flannel"
    echo "   kubectl logs -n kube-flannel -l app=flannel"
    echo "   kubectl describe nodes"
    exit 1
fi

echo "======================================"
echo ""
