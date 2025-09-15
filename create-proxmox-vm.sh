#!/bin/bash

# Script para criar VM no Proxmox com Ubuntu Noble Cloud Image
# Uso: ./create-vm.sh <nome_vm> <ip_static>
# Exemplo: ./create-vm.sh minha-vm 192.168.1.100

set -e  # Parar script em caso de erro

# =====================
# VALORES PADRÃO
# =====================
DEFAULT_GATEWAY="192.168.1.1"
DEFAULT_DNS1="8.8.8.8"
DEFAULT_DNS2="8.8.4.4"
DEFAULT_NETMASK="24"
DEFAULT_VM_STORAGE="local-lvm"
DEFAULT_VM_BRIDGE="vmbr0"
DEFAULT_VM_MEMORY="2048"
DEFAULT_VM_CORES="2"
DEFAULT_VM_DISK_SIZE="20G"
DEFAULT_CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
DEFAULT_VM_USER="devopsvanilla"
DEFAULT_VM_PASSWORD="AbCdEf1@3$"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se foi executado como root
if [[ $EUID -ne 0 ]]; then
   log_error "Este script deve ser executado como root"
   exit 1
fi

# Verificar argumentos
if [ $# -ne 2 ]; then
    echo "Uso: $0 <nome_vm> <ip_static>"
    echo "Exemplo: $0 minha-vm 192.168.1.100"
    exit 1
fi

# Parâmetros do script
VM_NAME="$1"
VM_IP="$2"

# Prompt para parâmetros customizáveis
read -rp "Gateway [default: $DEFAULT_GATEWAY]: " GATEWAY
GATEWAY=${GATEWAY:-$DEFAULT_GATEWAY}

read -rp "DNS primário [default: $DEFAULT_DNS1]: " DNS1
DNS1=${DNS1:-$DEFAULT_DNS1}
read -rp "DNS secundário [default: $DEFAULT_DNS2]: " DNS2
DNS2=${DNS2:-$DEFAULT_DNS2}

read -rp "Netmask (CIDR) [default: $DEFAULT_NETMASK]: " NETMASK
NETMASK=${NETMASK:-$DEFAULT_NETMASK}

read -rp "Storage [default: $DEFAULT_VM_STORAGE]: " VM_STORAGE
VM_STORAGE=${VM_STORAGE:-$DEFAULT_VM_STORAGE}

read -rp "Bridge de rede [default: $DEFAULT_VM_BRIDGE]: " VM_BRIDGE
VM_BRIDGE=${VM_BRIDGE:-$DEFAULT_VM_BRIDGE}

read -rp "Memória RAM (MB) [default: $DEFAULT_VM_MEMORY]: " VM_MEMORY
VM_MEMORY=${VM_MEMORY:-$DEFAULT_VM_MEMORY}

read -rp "Número de cores [default: $DEFAULT_VM_CORES]: " VM_CORES
VM_CORES=${VM_CORES:-$DEFAULT_VM_CORES}

read -rp "Tamanho do disco [default: $DEFAULT_VM_DISK_SIZE]: " VM_DISK_SIZE
VM_DISK_SIZE=${VM_DISK_SIZE:-$DEFAULT_VM_DISK_SIZE}

read -rp "URL da imagem cloud [default: $DEFAULT_CLOUD_IMAGE_URL]: " CLOUD_IMAGE_URL
CLOUD_IMAGE_URL=${CLOUD_IMAGE_URL:-$DEFAULT_CLOUD_IMAGE_URL}
CLOUD_IMAGE_FILE=$(basename "$CLOUD_IMAGE_URL")

read -rp "Usuário da VM [default: $DEFAULT_VM_USER]: " VM_USER
VM_USER=${VM_USER:-$DEFAULT_VM_USER}

read -s -rp "Senha da VM [default: $DEFAULT_VM_PASSWORD]: " VM_PASSWORD
echo
VM_PASSWORD=${VM_PASSWORD:-$DEFAULT_VM_PASSWORD}

# Função para encontrar próximo VMID disponível
find_next_vmid() {
    local vmid=100
    while qm status "$vmid" &>/dev/null; do
        ((vmid++))
    done
    echo "$vmid"
}

# Função para validar IP
validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for i in "${octets[@]}"; do
            if ((i > 255)); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Validar IP fornecido
if ! validate_ip "$VM_IP"; then
    log_error "IP inválido: $VM_IP"
    exit 1
fi

# Encontrar VMID disponível
VMID=$(find_next_vmid)
log_info "VMID selecionado: $VMID"

# Verificar se a VM com este nome já existe
if qm list | awk '{print $2}' | grep -Fxq "$VM_NAME"; then
    log_error "Uma VM com o nome '$VM_NAME' já existe"
    exit 1
fi

log_info "Iniciando criação da VM: $VM_NAME"
log_info "IP que será atribuído: $VM_IP/$NETMASK"
log_info "Gateway: $GATEWAY"

# Baixar imagem cloud se não existir
if [ ! -f "/tmp/$CLOUD_IMAGE_FILE" ]; then
    log_info "Baixando imagem cloud do Ubuntu Noble..."
    wget -O "/tmp/$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL"
    log_success "Imagem baixada com sucesso"
else
    log_info "Imagem cloud já existe, pulando download"
fi

# Criar VM base
log_info "Criando VM base..."
qm create "$VMID" \
    --name "$VM_NAME" \
    --description "Ubuntu 24.04 Noble - .BatOps" \
    --ostype l26 \
    --cpu cputype=host \
    --cores "$VM_CORES" \
    --sockets 1 \
    --memory "$VM_MEMORY" \
    --scsihw virtio-scsi-pci \
    --net0 "virtio,bridge=$VM_BRIDGE"

log_success "VM base criada com VMID: $VMID"

# Importar disco cloud image
log_info "Importando imagem cloud..."
qm importdisk "$VMID" "/tmp/$CLOUD_IMAGE_FILE" "$VM_STORAGE"

# Anexar disco à VM
log_info "Configurando disco de boot..."
qm set "$VMID" --scsi0 "$VM_STORAGE:vm-$VMID-disk-0"
qm set "$VMID" --boot c --bootdisk scsi0

# Redimensionar disco se necessário
log_info "Redimensionando disco para $VM_DISK_SIZE..."
qm resize "$VMID" scsi0 "$VM_DISK_SIZE"

# Adicionar drive cloud-init
log_info "Adicionando drive cloud-init..."
qm set "$VMID" --ide2 "$VM_STORAGE:cloudinit"

# Configurar cloud-init com IP estático
log_info "Configurando cloud-init..."
qm set "$VMID" --ipconfig0 "ip=$VM_IP/$NETMASK,gw=$GATEWAY"

# Configurar DNS
qm set "$VMID" --nameserver "$DNS1 $DNS2"

# Configurar usuário e senha
log_info "Configurando usuário: $VM_USER"
qm set "$VMID" --ciuser "$VM_USER" --cipassword "$VM_PASSWORD"

# Configurar para habilitar autenticação por senha (Ubuntu 24.04 issue fix)
log_info "Criando configuração customizada para habilitar SSH com senha..."
cat > "/var/lib/vz/snippets/$VM_NAME-user.yaml" << EOF
#cloud-config
ssh_pwauth: true
disable_root: false
users:
    - name: $VM_USER
        plain_text_passwd: "$VM_PASSWORD"
        shell: /bin/bash
        sudo: ALL=(ALL) NOPASSWD:ALL
        groups: [sudo]
chpasswd:
    expire: false
write_files:
  - path: /etc/ssh/sshd_config.d/99-cloud-init.conf
    content: |
      PasswordAuthentication yes
      PermitRootLogin yes
package_upgrade: true
packages:
    - qemu-guest-agent
runcmd:
    - systemctl enable qemu-guest-agent
    - systemctl start qemu-guest-agent
    - sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    - sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    - grep -q '^PasswordAuthentication yes' /etc/ssh/sshd_config || echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
    - systemctl restart sshd
	- systemctl enable qemu-guest-agent
  	- systemctl start qemu-guest-agent
EOF

# Aplicar configuração customizada
qm set "$VMID" --cicustom "user=local:snippets/$VM_NAME-user.yaml"

# Habilitar QEMU Guest Agent
log_info "Habilitando QEMU Guest Agent..."
qm set "$VMID" --agent enabled=1,fstrim_cloned_disks=1

# Configurar VGA para evitar problemas de console
qm set "$VMID" --vga qxl

# Regenerar imagem cloud-init
log_info "Regenerando configuração cloud-init..."
qm cloudinit update "$VMID"

# Perguntar se deve iniciar a VM
echo
read -rp "Deseja iniciar a VM agora? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Iniciando VM..."
    qm start "$VMID"
    
    log_info "Aguardando VM inicializar (isso pode levar alguns minutos)..."
    sleep 30
    
    # Verificar status
    if qm status "$VMID" | grep -q "running"; then
        log_success "VM iniciada com sucesso!"
        echo
        echo "=== INFORMAÇÕES DA VM ==="
        echo "Nome: $VM_NAME"
        echo "VMID: $VMID"
        echo "IP: $VM_IP"
        echo "Usuário: $VM_USER"
        echo "Senha: $VM_PASSWORD"
        echo "=========================="
        echo
    log_info "Para conectar via SSH: ssh $VM_USER@$VM_IP"
        log_warning "Aguarde alguns minutos para o cloud-init terminar a configuração"
    else
        log_error "Erro ao iniciar a VM"
    fi
else
    log_info "VM criada mas não foi iniciada"
    echo "Para iniciar manualmente: qm start $VMID"
fi

# Função para limpeza opcional
echo
read -rp "Deseja remover a imagem cloud baixada? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f "/tmp/$CLOUD_IMAGE_FILE"
    log_info "Imagem cloud removida"
fi

log_success "Script concluído!"
