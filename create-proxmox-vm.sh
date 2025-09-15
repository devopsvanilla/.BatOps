#!/bin/bash

# Script para criar VM no Proxmox com Ubuntu Noble Cloud Image
# Uso: ./create-vm.sh <nome_vm> <ip_static>
# Exemplo: ./create-vm.sh minha-vm 192.168.1.100

set -e # Parar script em caso de erro

# =====================
# VALORES PADRÃO
# =====================
DEFAULT_GATEWAY="192.168.0.1"
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

# Configurar usuário e senha via Proxmox cloud-init
log_info "Configurando usuário: $VM_USER"
qm set "$VMID" --ciuser "$VM_USER" --cipassword "$VM_PASSWORD"

# Selecionar chave pública SSH
echo
echo "=== CONFIGURAÇÃO SSH ==="
echo "1) Usar chave SSH existente"
echo "2) Pular configuração SSH (apenas senha)"
read -rp "Escolha uma opção [1-2]: " SSH_OPTION

SSH_KEY_CONTENT=""
if [[ "$SSH_OPTION" == "1" ]]; then
    PUB_KEYS=(~/.ssh/*.pub)
    if [ ${#PUB_KEYS[@]} -eq 0 ] || [ ! -f "${PUB_KEYS[0]}" ]; then
        log_warning "Nenhuma chave SSH encontrada em ~/.ssh/"
        log_info "Continuando apenas com autenticação por senha"
    else
        echo "Chaves públicas disponíveis:"
        select KEY_PATH in "${PUB_KEYS[@]}" "Pular SSH"; do
            if [[ "$KEY_PATH" == "Pular SSH" ]]; then
                log_info "SSH por chave pulado"
                break
            elif [[ -n "$KEY_PATH" && -f "$KEY_PATH" ]]; then
                SSH_KEY_CONTENT=$(<"$KEY_PATH")
                log_success "Chave SSH selecionada: $KEY_PATH"
                break
            else
                echo "Seleção inválida. Tente novamente."
            fi
        done
    fi
fi

# Criar cloud-init customizado completo
log_info "Criando configuração cloud-init customizada..."
cat > "/var/lib/vz/snippets/$VM_NAME-user.yaml" << EOF
#cloud-config
# Configuração completa para Ubuntu 24.04 Noble
ssh_pwauth: true
disable_root: false
chpasswd:
  expire: false

# Usuário principal
users:
  - name: $VM_USER
    passwd: \$(openssl passwd -6 "$VM_PASSWORD")
    lock_passwd: false
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: [sudo, adm, dialout, cdrom, floppy, audio, dip, video, plugdev, netdev, lxd]$(if [[ -n "$SSH_KEY_CONTENT" ]]; then echo "
    ssh_authorized_keys:
      - $SSH_KEY_CONTENT"; fi)

# Garantir que o usuário ubuntu padrão também funcione
  - name: ubuntu
    passwd: \$(openssl passwd -6 "$VM_PASSWORD")
    lock_passwd: false
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: [sudo, adm, dialout, cdrom, floppy, audio, dip, video, plugdev, netdev, lxd]$(if [[ -n "$SSH_KEY_CONTENT" ]]; then echo "
    ssh_authorized_keys:
      - $SSH_KEY_CONTENT"; fi)

# Instalar pacotes necessários
package_upgrade: true
packages:
  - qemu-guest-agent
  - cloud-init
  - openssh-server
  - curl
  - wget
  - vim
  - htop

# Comandos de configuração
runcmd:
  # Configurar QEMU Guest Agent
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  
  # Configurar SSH para permitir senha E chave
  - sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  
  # Garantir que cloud-init esteja habilitado
  - systemctl enable cloud-init-local
  - systemctl enable cloud-init
  - systemctl enable cloud-config
  - systemctl enable cloud-final
  
  # Reiniciar SSH
  - systemctl restart sshd
  
  # Atualizar sistema
  - apt update
  - apt upgrade -y
  
  # Limpeza final
  - apt autoremove -y
  - apt autoclean

# Configuração de timezone
timezone: America/Sao_Paulo

# Configuração de locale
locale: pt_BR.UTF-8

# Configurações finais
final_message: |
  Sistema Ubuntu 24.04 configurado com sucesso!
  
  Usuário: $VM_USER
  IP: $VM_IP
  
  Acesso SSH:
  - ssh $VM_USER@$VM_IP (com senha)$(if [[ -n "$SSH_KEY_CONTENT" ]]; then echo "
  - ssh -i chave_privada $VM_USER@$VM_IP (com chave)"; fi)
  
  Sistema pronto para uso!
EOF

# Aplicar configuração customizada
qm set "$VMID" --cicustom "user=local:snippets/$VM_NAME-user.yaml"

# Habilitar QEMU Guest Agent
log_info "Habilitando QEMU Guest Agent..."
qm set "$VMID" --agent enabled=1,fstrim_cloned_disks=1

# Configurar VGA para evitar problemas de console
qm set "$VMID" --vga qxl

# Configurar console serial
qm set "$VMID" --serial0 socket --vga serial0

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
        log_info "Opções de conexão SSH:"
        log_info "1) Com senha: ssh $VM_USER@$VM_IP"
        if [[ -n "$SSH_KEY_CONTENT" ]]; then
            log_info "2) Com chave: ssh -i ~/.ssh/chave_privada $VM_USER@$VM_IP"
        fi
        log_info "3) Usuário ubuntu: ssh ubuntu@$VM_IP (mesma senha)"
        echo
        log_warning "IMPORTANTE: Aguarde 3-5 minutos para o cloud-init terminar completamente"
        log_warning "Se não conseguir conectar imediatamente, aguarde mais alguns minutos"
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

echo
log_success "Script concluído!"
echo
log_info "RESUMO DA CONFIGURAÇÃO:"
echo "- VM criada com cloud-init completo"
echo "- Autenticação por SENHA habilitada"
if [[ -n "$SSH_KEY_CONTENT" ]]; then
    echo "- Autenticação por CHAVE SSH habilitada"
fi
echo "- Usuários criados: $VM_USER e ubuntu"
echo "- Cloud-init instalado e configurado"
echo "- QEMU Guest Agent habilitado"
