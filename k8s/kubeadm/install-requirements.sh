#!/bin/bash

# Script para preparar Ubuntu 24.04 LTS para instalação do Kubernetes via kubeadm
# Autor: DevOps Vanilla
# Data: 2026-03-05

set -e

echo "======================================"
echo "Preparando Ubuntu 24.04 para Kubernetes"
echo "======================================"

# Verifica se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "Por favor, execute como root ou com sudo"
    exit 1
fi

# 1. Desabilitar SWAP
echo ""
echo "[1/9] Desabilitando SWAP..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
echo "SWAP desabilitado com sucesso"

# 2. Carregar módulos do kernel necessários
echo ""
echo "[2/9] Configurando módulos do kernel..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
echo "Módulos carregados com sucesso"

# 3. Configurar parâmetros sysctl necessários
echo ""
echo "[3/9] Configurando parâmetros sysctl..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system
echo "Parâmetros sysctl configurados com sucesso"

# 4. Instalar dependências
echo ""
echo "[4/9] Instalando dependências..."
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gpg software-properties-common
echo "Dependências instaladas com sucesso"

# 5. Instalar containerd
echo ""
echo "[5/9] Instalando containerd..."
apt-get install -y containerd

# Configurar containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# Habilitar SystemdCgroup
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd
echo "Containerd instalado e configurado com sucesso"

# 6. Adicionar repositório do Kubernetes
echo ""
echo "[6/9] Adicionando repositório do Kubernetes..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
echo "Repositório adicionado com sucesso"

# 7. Instalar kubeadm, kubelet e kubectl
echo ""
echo "[7/9] Instalando kubeadm, kubelet e kubectl..."
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
echo "Kubernetes tools instalados com sucesso"

# 8. Habilitar kubelet
echo ""
echo "[8/9] Habilitando kubelet..."
systemctl enable kubelet
echo "Kubelet habilitado com sucesso"

# 9. Verificar instalação
echo ""
echo "[9/9] Verificando instalação..."
echo "Versão do kubeadm:"
kubeadm version
echo ""
echo "Versão do kubelet:"
kubelet --version
echo ""
echo "Versão do kubectl:"
kubectl version --client
echo ""
echo "Status do containerd:"
systemctl status containerd --no-pager | head -3

echo ""
echo "======================================"
echo "✓ Sistema preparado com sucesso!"
echo "======================================"
echo ""
echo "Próximos passos:"
echo "  - Para inicializar o control plane (master):"
echo "    kubeadm init --pod-network-cidr=10.244.0.0/16"
echo ""
echo "  - Para configurar kubectl:"
echo "    mkdir -p \$HOME/.kube"
echo "    sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config"
echo "    sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
echo ""
echo "  - Para instalar plugin de rede (exemplo com Flannel):"
echo "    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"
echo ""
echo "  - Para adicionar workers ao cluster, execute o comando 'kubeadm join' fornecido após o init"
echo ""
