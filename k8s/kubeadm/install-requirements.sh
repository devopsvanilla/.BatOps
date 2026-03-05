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

# Verificar se Kubernetes já está instalado
echo ""
echo "Verificando instalações existentes..."

KUBEADM_INSTALLED=false
KUBECTL_INSTALLED=false
KUBELET_INSTALLED=false
CONTAINERD_INSTALLED=false

if command -v kubeadm &> /dev/null; then
    KUBEADM_INSTALLED=true
    echo "✓ kubeadm encontrado: $(kubeadm version -o short 2>/dev/null || echo 'versão desconhecida')"
fi

if command -v kubectl &> /dev/null; then
    KUBECTL_INSTALLED=true
    echo "✓ kubectl encontrado: $(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*' | cut -d'"' -f4 || echo 'versão desconhecida')"
fi

if command -v kubelet &> /dev/null; then
    KUBELET_INSTALLED=true
    echo "✓ kubelet encontrado: $(kubelet --version 2>/dev/null | awk '{print $2}' || echo 'versão desconhecida')"
fi

if command -v containerd &> /dev/null; then
    CONTAINERD_INSTALLED=true
    echo "✓ containerd encontrado: $(containerd --version 2>/dev/null | awk '{print $3}' || echo 'versão desconhecida')"
fi

# Se houver instalação existente, perguntar ao usuário
if [ "$KUBEADM_INSTALLED" = true ] || [ "$KUBECTL_INSTALLED" = true ] || [ "$KUBELET_INSTALLED" = true ] || [ "$CONTAINERD_INSTALLED" = true ]; then
    echo ""
    echo "⚠️  ATENÇÃO: Componentes do Kubernetes já estão instalados!"
    echo ""
    echo "Opções:"
    echo "  1) Continuar e REINSTALAR (remove e reinstala tudo)"
    echo "  2) Atualizar somente componentes faltantes"
    echo "  3) Cancelar e sair"
    echo ""
    read -p "Escolha uma opção [1/2/3]: " choice
    
    case $choice in
        1)
            echo ""
            echo "🔄 Removendo instalações existentes..."
            
            # Parar serviços se estiverem rodando
            systemctl stop kubelet 2>/dev/null || true
            systemctl stop containerd 2>/dev/null || true
            
            # Remover pacotes
            apt-get remove -y kubeadm kubectl kubelet containerd 2>/dev/null || true
            apt-get purge -y kubeadm kubectl kubelet containerd 2>/dev/null || true
            apt-get autoremove -y
            
            # Limpar configurações
            rm -rf /etc/kubernetes
            rm -rf /var/lib/kubelet
            rm -rf /var/lib/etcd
            rm -rf /etc/containerd
            rm -rf /etc/cni
            rm -rf /opt/cni
            rm -rf $HOME/.kube
            rm -rf /etc/apt/sources.list.d/kubernetes.list
            rm -rf /etc/apt/keyrings/kubernetes-apt-keyring.gpg
            
            # Remover hold de pacotes
            apt-mark unhold kubelet kubeadm kubectl 2>/dev/null || true
            
            echo "✓ Remoção concluída. Prosseguindo com instalação limpa..."
            ;;
        2)
            echo ""
            echo "ℹ️  Modo de atualização: instalará apenas componentes faltantes"
            echo "   (Configurações existentes serão preservadas)"
            ;;
        3)
            echo ""
            echo "❌ Instalação cancelada pelo usuário"
            exit 0
            ;;
        *)
            echo ""
            echo "❌ Opção inválida. Instalação cancelada."
            exit 1
            ;;
    esac
else
    echo "✓ Nenhuma instalação prévia detectada"
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
apt-get install -y apt-transport-https ca-certificates curl gpg software-properties-common conntrack socat ipset
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

# Atualizar versão da imagem pause para compatibilidade com Kubernetes 1.35
sed -i 's/pause:3\.[0-9]\+/pause:3.10/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd
echo "Containerd instalado e configurado com sucesso"

# 6. Adicionar repositório do Kubernetes
echo ""
echo "[6/9] Adicionando repositório do Kubernetes..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

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
