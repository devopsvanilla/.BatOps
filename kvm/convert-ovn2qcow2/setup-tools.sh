#!/usr/bin/env bash
# TODO: Revisar e adicionar set -euo pipefail — Issue #1

# Cores para feedback
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

set -e

echo -e "${GREEN}🛠️  Instalador de Dependências BatOps (KVM/virt-v2v)${NC}"
echo "-------------------------------------------------------"

# 1. Verificação de Root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ Erro: Este script precisa de privilégios de root.${NC}"
  echo "Execute: sudo ./setup-tools.sh"
  exit 1
fi

# 2. Identificação de Ambiente
IS_WSL=false
if grep -qi "microsoft" /proc/version; then
    IS_WSL=true
    echo -e "${YELLOW}🔍 Detetado: Subsistema Windows para Linux (WSL2)${NC}"
else
    echo -e "${YELLOW}🔍 Detetado: Ubuntu Nativo / VM${NC}"
fi

# 3. Instalação de Pacotes
echo "📦 Atualizando repositórios e instalando binários..."
apt update -y

# binutils contém o 'strings'
# libxml2-utils contém o 'xmllint'
PACKAGES=(
    virt-v2v
    qemu-utils
    libguestfs-tools
    libxml2-utils
    binutils
    cpu-checker
    libvirt-daemon-system
    libvirt-clients
    rhsrvany
    ntfs-3g
    nbdkit
)

apt install -y "${PACKAGES[@]}"

# 4. Configuração de Kernel (Específico para funcionamento do Libguestfs/virt-v2v)
if [ "$IS_WSL" = true ]; then
    echo "⚙️  Instalando Kernel virtual para WSL2..."
    apt install -y linux-image-virtual
    # Garante que o kernel em /boot é legível para ferramentas de disco
    chmod 0644 /boot/vmlinuz-* || true

    # Cria o Fixed Appliance para evitar erros de boot no WSL2
    echo "🔨 Gerando Appliance fixo para Libguestfs..."
    mkdir -p /usr/lib/x86_64-linux-gnu/guestfs
    libguestfs-make-fixed-appliance /usr/lib/x86_64-linux-gnu/guestfs
else
    echo "⚙️  Configurando Kernel para Ambiente Nativo..."
    # Em nativo, geralmente apenas garantimos que o kernel atual é acessível
    chmod 0644 /boot/vmlinuz-* || true
fi

# 5. Permissões de Usuário e Hardware
ACTUAL_USER=${SUDO_USER:-$USER}
echo -e "🔐 Configurando grupos para: ${YELLOW}$ACTUAL_USER${NC}"

groupadd -f kvm
groupadd -f libvirt
usermod -aG kvm "$ACTUAL_USER"
usermod -aG libvirt "$ACTUAL_USER"

# Acesso direto ao acelerador KVM
if [ -e /dev/kvm ]; then
    chmod 666 /dev/kvm
fi

echo "-------------------------------------------------------"
echo -e "${GREEN}✅ Dependências instaladas com sucesso!${NC}"
echo -e "${YELLOW}👉 PRÓXIMO PASSO OBRIGATÓRIO:${NC}"
echo -e "Para aplicar as permissões de grupo sem reiniciar o Windows/PC,"
echo -e "execute o seguinte comando no seu terminal atual:"
echo -e "   ${GREEN}newgrp kvm && newgrp libvirt${NC}"
echo "-------------------------------------------------------"
