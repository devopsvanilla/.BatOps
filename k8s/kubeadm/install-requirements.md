# Install Kubernetes Requirements

Script para preparar um servidor Ubuntu 24.04 LTS com todos os requisitos necessários para instalação do Kubernetes via kubeadm.

## 📋 O que o Script Faz

Este script automatiza a preparação completa do sistema operacional Ubuntu 24.04 LTS para receber o Kubernetes. Ele executa as seguintes tarefas:

### 0. **Detecção de Instalação Existente**
- Verifica se kubeadm, kubectl, kubelet ou containerd já estão instalados
- Exibe versões encontradas
- Oferece 3 opções ao usuário:
  - **Opção 1**: Reinstalar completamente (remove tudo e reinstala do zero)
  - **Opção 2**: Atualizar apenas componentes faltantes (preserva configurações)
  - **Opção 3**: Cancelar a execução
- Se escolher reinstalação completa, limpa:
  - Serviços (para kubelet e containerd)
  - Pacotes instalados
  - Configurações em /etc/kubernetes, /var/lib/kubelet, /etc/containerd
  - Diretórios CNI e kubectl config
  - Repositório e chaves antigas do Kubernetes

### 1. **Desabilita SWAP**
- Remove a memória swap ativa
- Comenta entradas de swap no `/etc/fstab`
- Requisito obrigatório do Kubernetes

### 2. **Carrega Módulos do Kernel**
- `overlay`: necessário para o overlay filesystem do containerd
- `br_netfilter`: permite que o iptables veja o tráfego em bridges

### 3. **Configura Parâmetros de Rede (sysctl)**
- `net.bridge.bridge-nf-call-iptables = 1`
- `net.bridge.bridge-nf-call-ip6tables = 1`
- `net.ipv4.ip_forward = 1`

### 4. **Instala Dependências do Sistema**
- apt-transport-https
- ca-certificates
- curl
- gpg
- software-properties-common
- conntrack (rastreamento de conexões - obrigatório)
- socat (relay de sockets - usado por port-forwarding)
- ipset (gerenciamento de conjuntos de IPs - usado por kube-proxy)

### 5. **Instala e Configura Containerd**
- Instala o containerd como container runtime
- Gera configuração padrão
- Habilita SystemdCgroup (requerido pelo Kubernetes)
- Atualiza imagem pause para versão 3.10 (compatível com K8s 1.35)
- Reinicia e habilita o serviço

### 6. **Adiciona Repositório Oficial do Kubernetes**
- Adiciona chave GPG do repositório
- Configura repositório stable v1.35 (versão mais recente)
- Atualiza lista de pacotes

### 7. **Instala Ferramentas do Kubernetes**
- `kubeadm`: ferramenta para criar e gerenciar o cluster
- `kubelet`: agente que executa em todos os nós
- `kubectl`: cliente CLI do Kubernetes
- Bloqueia atualizações automáticas (`apt-mark hold`)

### 8. **Habilita o Kubelet**
- Configura o kubelet para iniciar automaticamente

### 9. **Verifica a Instalação**
- Exibe versões instaladas
- Verifica status do containerd
- Mostra próximos passos

## 🚀 Como Executar

### Pré-requisitos
- Ubuntu 24.04 LTS instalado
- Acesso root ou sudo
- Conexão com a internet

### Execução

```bash
# Navegar até o diretório
cd /home/devopsvanilla/.BatOps/k8s/kubeadm

# Dar permissão de execução (se necessário)
chmod +x install-requirements.sh

# Executar o script com privilégios root
sudo ./install-requirements.sh
```

### Execução com Instalação Existente

Se você já tiver componentes do Kubernetes instalados, o script detectará automaticamente e apresentará opções:

```bash
sudo ./install-requirements.sh

# Saída esperada:
Verificando instalações existentes...
✓ kubeadm encontrado: v1.31.14
✓ kubectl encontrado: v1.31.14
✓ kubelet encontrado: v1.31.14
✓ containerd encontrado: 1.7.x

⚠️  ATENÇÃO: Componentes do Kubernetes já estão instalados!

Opções:
  1) Continuar e REINSTALAR (remove e reinstala tudo)
  2) Atualizar somente componentes faltantes
  3) Cancelar e sair

Escolha uma opção [1/2/3]:
```

**Recomendações:**
- **Opção 1**: Use quando quiser uma instalação limpa ou houver problemas de configuração  - Executa `kubeadm reset` para desmanchar o cluster
  - Desmonta volumes ativos
  - Para serviços (kubelet e containerd)
  - Remove pacotes instalados
  - Limpa configurações em /etc/kubernetes, /var/lib/kubelet, /etc/containerd
  - Limpa diretórios CNI e kubectl config
  - Limpa repositório e chaves antigas do Kubernetes
  - Limpa regras iptables do Kubernetes- **Opção 2**: Use para adicionar apenas o que está faltando
- **Opção 3**: Use para verificar o que está instalado sem fazer mudanças

### Tempo Estimado
A execução completa leva aproximadamente **5-10 minutos**, dependendo da velocidade da conexão de internet e do hardware.

## ✅ Como Testar a Execução

Após a execução do script, verifique se tudo foi instalado corretamente:

### 1. Verificar SWAP está desabilitado
```bash
free -h
# A linha "Swap" deve mostrar 0B ou estar ausente

cat /proc/swaps
# Deve estar vazio
```

### 2. Verificar módulos do kernel carregados
```bash
lsmod | grep overlay
lsmod | grep br_netfilter
# Ambos devem retornar linhas indicando que os módulos estão carregados
```

### 3. Verificar parâmetros sysctl
```bash
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
sysctl net.ipv4.ip_forward
# Todos devem retornar = 1
```

### 4. Verificar containerd
```bash
systemctl status containerd
# Deve mostrar "active (running)"

containerd --version
# Deve exibir a versão instalada
```

### 5. Verificar ferramentas do Kubernetes
```bash
kubeadm version
kubelet --version
kubectl version --client
# Todas devem exibir a versão instalada (v1.35.x)
```

### 6. Verificar kubelet está habilitado
```bash
systemctl is-enabled kubelet
# Deve retornar "enabled"
```

### 7. Verificar repositório do Kubernetes
```bash
apt-cache policy kubeadm
# Deve mostrar o repositório pkgs.k8s.io na lista
```

## 📝 Próximos Passos

Após a execução bem-sucedida do script, você pode:

### Para Inicializar um Control Plane (Master Node)

```bash
# Inicializar o cluster (ajuste a CIDR conforme necessário)
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Configurar kubectl para o usuário atual
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Instalar plugin de rede (exemplo: Flannel)
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Verificar nodes
kubectl get nodes
```

### Para Adicionar um Worker Node

No control plane, após o `kubeadm init`, você receberá um comando similar a:
```bash
kubeadm join <IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>
```

Execute este comando no worker node (após executar o `install-requirements.sh`).

## 🔍 Troubleshooting

### Erro: "Package containerd is not available"
Solução: Execute `sudo apt-get update` e tente novamente.

### Erro: "Failed to load module br_netfilter"
Solução: Verifique se o kernel suporta o módulo. Para Ubuntu 24.04, deve funcionar normalmente.

### Erro ao adicionar repositório do Kubernetes
Solução: Verifique conexão com a internet e existência do diretório `/etc/apt/keyrings`:
```bash
sudo mkdir -p /etc/apt/keyrings
```

### Containerd não inicia
Solução: Verifique logs do serviço:
```bash
sudo journalctl -xeu containerd
```

## 📚 Referências

- [Kubernetes Official Documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [Container Runtime Interface (CRI)](https://kubernetes.io/docs/concepts/architecture/cri/)
- [Containerd Documentation](https://containerd.io/docs/)

## ⚠️ Importante

- Este script é **destrutivo** para configurações de swap e rede
- Execute apenas em servidores dedicados ao Kubernetes
- Faça backup de configurações importantes antes de executar
- O script usa `set -e`, então qualquer erro interromperá a execução
- As versões instaladas são baseadas no repositório stable v1.31

## 📄 Licença

Este script faz parte do repositório BatOps - DevOps Vanilla

---

**Autor**: DevOps Vanilla  
**Data**: 05/03/2026  
**Versão**: 1.0
