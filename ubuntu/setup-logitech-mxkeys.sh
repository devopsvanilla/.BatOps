#!/usr/bin/bash
#
# Script para configurar Ubuntu com Logitech MX Keys
# Layout: US (Internacional com suporte a Português do Brasil via SSH)
# Autor: DevOpsVanilla
# Data: $(date +%Y-%m-%d)
#

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funções
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se é root
if [[ $EUID -ne 0 ]]; then
   log_error "Este script deve ser executado como root (use sudo)"
   exit 1
fi

log_info "========================================="
log_info "Configurando Ubuntu para Logitech MX Keys"
log_info "Layout: US (com suporte a Português BR)"
log_info "========================================="
log_info ""

# 1. Atualizar repositórios
log_info "Atualizando repositórios do sistema..."
apt-get update -qq

# 2. Instalar ferramentas necessárias
log_info "Instalando pacotes necessários..."
apt-get install -y -qq \
    keyboard-configuration \
    xserver-xorg-input-libinput \
    locales \
    console-data \
    udev \
    xkb-data

# 3. Configurar locale para Português do Brasil
log_info "Configurando locale para Português do Brasil..."
sed -i '/pt_BR.UTF-8/s/^# //g' /etc/locale.gen
locale-gen pt_BR.UTF-8 > /dev/null 2>&1 || true

# Adicionar locale alternativa para SSH
if ! grep -q "export LANG=" /etc/environment; then
    echo "LANG=pt_BR.UTF-8" >> /etc/environment
else
    sed -i 's/^export LANG=.*/export LANG=pt_BR.UTF-8/' /etc/environment
fi

if ! grep -q "export LC_ALL=" /etc/environment; then
    echo "LC_ALL=pt_BR.UTF-8" >> /etc/environment
else
    sed -i 's/^export LC_ALL=.*/export LC_ALL=pt_BR.UTF-8/' /etc/environment
fi

# 4. Configurar layout de teclado para US (International)
log_info "Configurando layout de teclado para US (International)..."

# Arquivo de configuração do console
cat > /etc/default/keyboard << 'EOF'
# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page for more information
# on keyboard configuration.

XKBMODEL="logitech_mx"
XKBLAYOUT="us"
XKBVARIANT="intl"
XKBOPTIONS=""

BACKSPACE="guess"
EOF

# 5. Configurar X11 para SSH forwarding com teclado correto
log_info "Configurando X11 para SSH forwarding..."
if ! grep -q "XkbLayout" /etc/X11/xorg.conf.d/00-keyboard.conf 2>/dev/null; then
    mkdir -p /etc/X11/xorg.conf.d
    cat > /etc/X11/xorg.conf.d/00-keyboard.conf << 'EOF'
# Read and parsed by systemd-localed. It's probably wise not to edit this file
# manually too freely.
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "us"
        Option "XkbVariant" "intl"
        Option "XkbModel" "logitech_mx"
EndSection
EOF
fi

# 6. Configurar SSH para preservar locale
log_info "Configurando SSH para preservar configurações de locale..."
if grep -q "^#AcceptLocale" /etc/ssh/sshd_config; then
    sed -i 's/^#AcceptLocale .*/AcceptLocale pt_BR.UTF-8 en_US.UTF-8 C.UTF-8/' /etc/ssh/sshd_config
elif ! grep -q "^AcceptLocale" /etc/ssh/sshd_config; then
    echo "" >> /etc/ssh/sshd_config
    echo "# Suporte a locale do cliente SSH" >> /etc/ssh/sshd_config
    echo "AcceptLocale pt_BR.UTF-8 en_US.UTF-8 C.UTF-8" >> /etc/ssh/sshd_config
fi

# Validar configuração SSH
if sshd -t > /dev/null 2>&1; then
    log_info "Recarregando configuração SSH..."
    systemctl reload sshd
else
    log_warn "Erro ao validar configuração SSH, pulando reload"
fi

# 7. Configurar bash para Português
log_info "Configurando shell para Português do Brasil..."
if ! grep -q "export LANG=pt_BR.UTF-8" /etc/profile.d/pt_br.sh 2>/dev/null; then
    cat > /etc/profile.d/pt_br.sh << 'EOF'
#!/bin/bash
# Configuração de locale para Português do Brasil

export LANG=pt_BR.UTF-8
export LC_ALL=pt_BR.UTF-8
export LC_MESSAGES=pt_BR.UTF-8
export LANGUAGE=pt_BR:pt:en
EOF
    chmod 644 /etc/profile.d/pt_br.sh
fi

# 8. Configurar udev rules para Logitech MX Keys
log_info "Configurando udev rules para Logitech MX Keys..."
cat > /etc/udev/rules.d/10-logitech-mx.rules << 'EOF'
# Logitech MX Keys
# USB Vendor ID: 046d (Logitech)

# MX Keys standard
SUBSYSTEMS=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="408[0-2]", MODE="0666", ENV{ID_INPUT_KEYBOARD}="1"

# MX Keys Mini
SUBSYSTEMS=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="408[3-9]", MODE="0666", ENV{ID_INPUT_KEYBOARD}="1"

# MX Keys for Mac
SUBSYSTEMS=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="409[0-9]", MODE="0666", ENV{ID_INPUT_KEYBOARD}="1"
EOF

# Recarregar udev rules
udevadm control --reload-rules
udevadm trigger

# 9. Instalar ferramentas adicionais (opcional)
log_info "Instalando ferramentas adicionais para gerenciamento de teclado..."
apt-get install -y -qq \
    setxkbmap \
    xmodmap \
    dconf-cli || true

# 10. Resumo das configurações
log_info ""
log_info "========================================="
log_info "Configuração concluída com sucesso!"
log_info "========================================="
log_info ""
log_info "Configurações aplicadas:"
log_info "  • Layout de teclado: US (International)"
log_info "  • Modelo de teclado: Logitech MX Keys"
log_info "  • Locale: Português do Brasil (pt_BR.UTF-8)"
log_info "  • SSH: Configurado para aceitar locale remoto"
log_info ""
log_info "Para aplicar as mudanças:"
log_info "  1. SSH: Logout e login novamente"
log_info "  2. Console: Reinicie o sistema (sudo reboot)"
log_info ""
log_info "Teste a configuração com:"
log_info "  $ localectl status"
log_info "  $ setxkbmap -query"
log_info ""