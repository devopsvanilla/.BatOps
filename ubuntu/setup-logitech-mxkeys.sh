#!/usr/bin/bash
#
# Script para configurar Ubuntu com Logitech MX Keys
# Layout: US com suporte a Português do Brasil e ç com AltGr+c
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

# 4. Configurar layout de teclado para US (padrão)
log_info "Configurando layout de teclado para US (padrão)..."

# Arquivo de configuração do console
cat > /etc/default/keyboard << 'EOF'
# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page for more information
# on keyboard configuration.

XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT=""
XKBOPTIONS=""

BACKSPACE="guess"
EOF

# 5. Criar arquivo .Xmodmap para mapeamento correto de teclas
log_info "Configurando mapeamento de teclado customizado (ç com AltGr+c)..."

# Criar script de inicialização para xmodmap
cat > /etc/profile.d/xmodmap-init.sh << 'XEOF'
#!/bin/bash
# Arquivo de inicialização para xmodmap - carrega configuração customizada

if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    if [ -f ~/.Xmodmap ]; then
        xmodmap ~/.Xmodmap 2>/dev/null || true
    fi
fi
XEOF

chmod 644 /etc/profile.d/xmodmap-init.sh

# Criar arquivo .Xmodmap para cada usuário (excluindo root)
log_info "Gerando arquivo .Xmodmap para usuários com layout US correto..."

for home_dir in /home/*; do
    if [ -d "$home_dir" ]; then
        username=$(basename "$home_dir")
        xmodmap_file="$home_dir/.Xmodmap"
        
        # Criar .Xmodmap com as teclas críticas configuradas corretamente
        cat > "$xmodmap_file" << 'XEOF'
! Arquivo de configuração XKeyboard para layout US com ç
! Layout: US (padrão pc105) com AltGr+c = ç
! 
! Este arquivo garante que o teclado funcione corretamente
! Especialmente importante para acesso SSH onde o servidor
! pode remapear as teclas incorretamente

! keycode 47: semicolon (;)
keycode  47 = semicolon colon semicolon colon paragraph degree paragraph

! keycode 54: c (adiciona ç na posição AltGr+c)
keycode  54 = c C c C ccedilla Ccedilla ccedilla

! keycode 59: comma (,) e cedilla (ç)
keycode  59 = comma less comma less ccedilla Ccedilla ccedilla

! keycode 61: slash (/) - CRÍTICO: deve permanecer como slash
keycode  61 = slash question slash question questiondown dead_hook questiondown
XEOF
        
        # Ajustar permissões para o usuário
        owner=$(stat -c '%U:%G' "$home_dir" 2>/dev/null | cut -d: -f1)
        if [ ! -z "$owner" ] && [ "$owner" != "root" ]; then
            chown "$owner:$owner" "$xmodmap_file" 2>/dev/null || true
            chmod 644 "$xmodmap_file"
            log_info "  • .Xmodmap criado para $username"
        fi
    fi
done

# 6. Configurar SSH para preservar locale
log_info "Configurando SSH para preservar configurações de locale..."
if grep -q "^#AcceptLocale" /etc/ssh/sshd_config; then
    sed -i 's/^#AcceptLocale .*/AcceptLocale pt_BR.UTF-8 en_US.UTF-8 C.UTF-8/' /etc/ssh/sshd_config
elif ! grep -q "^AcceptLocale" /etc/ssh/sshd_config; then
    echo "" >> /etc/ssh/sshd_config
    echo "# Suporte a locale do cliente SSH" >> /etc/ssh/sshd_config
    echo "AcceptLocale pt_BR.UTF-8 en_US.UTF-8 C.UTF-8" >> /etc/ssh/sshd_config
fi

# Também aceitar XKBLAYOUT e variáveis relacionadas ao teclado via SSH
if ! grep -q "^AcceptEnv XKBLAYOUT" /etc/ssh/sshd_config; then
    echo "AcceptEnv XKBLAYOUT XKBVARIANT XKBMODEL XKBOPTIONS" >> /etc/ssh/sshd_config
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

# 8. Configurar udev rules para qualquer teclado USB
log_info "Configurando udev rules para teclados USB..."
cat > /etc/udev/rules.d/10-keyboard-usb.rules << 'EOF'
# Teclados USB - Logitech MX Keys e outros modelos
# USB Vendor ID: 046d (Logitech)

# MX Keys standard
SUBSYSTEMS=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="408[0-2]", MODE="0666", ENV{ID_INPUT_KEYBOARD}="1"

# MX Keys Mini
SUBSYSTEMS=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="408[3-9]", MODE="0666", ENV{ID_INPUT_KEYBOARD}="1"

# MX Keys for Mac
SUBSYSTEMS=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="409[0-9]", MODE="0666", ENV{ID_INPUT_KEYBOARD}="1"

# Teclados USB genéricos
SUBSYSTEMS=="usb", ATTRS{bInterfaceClass}=="03", ATTRS{bInterfaceSubClass}=="01", MODE="0666", ENV{ID_INPUT_KEYBOARD}="1"
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
log_info "  • Layout de teclado: US (padrão pc105)"
log_info "  • Mapeamento customizado: AltGr+c = ç"
log_info "  • Tecla /: slash (/) - corrigida"
log_info "  • Locale: Português do Brasil (pt_BR.UTF-8)"
log_info "  • SSH: Configurado para aceitar locale remoto"
log_info ""
log_info "Para aplicar as mudanças imediatamente:"
log_info "  1. Carregar .Xmodmap:"
log_info "     $ xmodmap ~/.Xmodmap"
log_info ""
log_info "  2. Para aplicar em novo login:"
log_info "     $ source ~/.bashrc"
log_info ""
log_info "  3. Ou fazer logout e login novamente"
log_info ""
log_info "Teste a configuração com:"
log_info "  $ setxkbmap -query"
log_info "  $ xmodmap -pke | grep 'keycode  61'"
log_info "  $ echo 'Teste / e ;'"
log_info ""
log_info "Para usar ç: pressione AltGr+c"
log_info ""
