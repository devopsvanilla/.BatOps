#!/bin/bash

# Script para inicializar o Kubernetes Master (Control Plane)
# com as melhores práticas e evitando alertas conhecidos
# Autor: DevOps Vanilla
# Data: 2026-03-06

set -e

echo "======================================"
echo "Inicializando Kubernetes Control Plane"
echo "======================================"

# Verifica se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Por favor, execute como root ou com sudo"
    exit 1
fi

# Verificar se kubeadm já foi inicializado
if [ -f /etc/kubernetes/admin.conf ]; then
    echo ""
    echo "⚠️  ATENÇÃO: Kubernetes já foi inicializado neste node!"
    echo ""
    read -p "Deseja reinicializar? (s/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Cancelado pelo usuário"
        exit 0
    fi
    
    echo ""
    echo "🔄 Resetando cluster existente..."
    kubeadm reset -f
fi

echo ""
echo "[1/3] Pré-carregando imagens de contêiner..."
echo "      (Isso pode levar alguns minutos)"
kubeadm config images pull
echo "✓ Imagens carregadas com sucesso"

echo ""
echo "[2/3] Inicializando control plane..."
echo "      Network CIDR: 10.244.0.0/16 (Flannel)"
kubeadm init --pod-network-cidr=10.244.0.0/16

echo ""
echo "[3/3] Configurando kubectl..."
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
echo "✓ Kubectl configurado"

echo ""
echo "======================================"
echo "✓ Control Plane inicializado com sucesso!"
echo "======================================"
echo ""
echo "Próximos passos:"
echo ""
echo "  1) Instalar o plugin de rede (Flannel):"
echo "     kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"
echo ""
echo "  2) Aguardar os pods ficarem prontos:"
echo "     kubectl get nodes          # Aguarde aparecer 'Ready'"
echo "     kubectl get pods -n kube-system"
echo ""
echo "  3) Salvar o comando 'kubeadm join' para adicionar workers:"
echo "     (Salve o comando que apareceu acima)"
echo ""
echo "  4) Adicionar nodes workers (em cada worker, como root):"
echo "     kubeadm join <MASTER_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash <HASH>"
echo ""
