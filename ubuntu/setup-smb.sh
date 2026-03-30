#!/usr/bin/env bash
# TODO: Revisar e adicionar set -euo pipefail — Issue #1

# Script interativo para configurar compartilhamento SMB no Ubuntu
# Autor: devopsvanilla
# Data: 2026-03-28

# Funções de cor e emojis
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color

emoji_info="📌"
emoji_ok="✅"
emoji_error="❌"
emoji_warn="⚠️"
emoji_prompt="🤔"

function info()    { echo -e "${BLUE}${emoji_info} $1${NC}"; }
function ok()      { echo -e "${GREEN}${emoji_ok} $1${NC}"; }
function error()   { echo -e "${RED}${emoji_error} $1${NC}"; }
function warn()    { echo -e "${YELLOW}${emoji_warn} $1${NC}"; }
function prompt()  { echo -en "${CYAN}${emoji_prompt} $1${NC} "; }

# Verifica se está rodando como root
if [[ $EUID -ne 0 ]]; then
  error "Este script precisa ser executado como root. Use sudo!"
  exit 1
fi

info "Verificando dependências..."
DEPS=(samba smbclient)
MISSING=()
for pkg in "${DEPS[@]}"; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    MISSING+=("$pkg")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  warn "Dependências ausentes: ${MISSING[*]}"
  info "Atualizando repositórios e instalando dependências..."
  apt update && apt install -y "${MISSING[@]}"
  if [[ $? -ne 0 ]]; then
    error "Falha ao instalar dependências. Corrija e tente novamente."
    exit 2
  fi
  ok "Dependências instaladas com sucesso."
else
  ok "Todas as dependências já estão instaladas."
fi

# Prompt para diretório a ser compartilhado
while true; do
  prompt "Digite o caminho ABSOLUTO do diretório a ser compartilhado (ex: /srv/compartilhado):"
  read DIR_SHARE
  [[ -z "$DIR_SHARE" ]] && warn "Caminho não pode ser vazio." && continue
  if [[ ! -d "$DIR_SHARE" ]]; then
    warn "Diretório não existe. Criar? (s/n)"
    read resp
    if [[ "$resp" =~ ^[sS]$ ]]; then
      mkdir -p "$DIR_SHARE"
      ok "Diretório criado: $DIR_SHARE"
    else
      continue
    fi
  fi
  break
done

# Prompt para nome do compartilhamento
while true; do
  prompt "Digite o NOME do compartilhamento (ex: arquivos):"
  read SHARE_NAME
  [[ -z "$SHARE_NAME" ]] && warn "Nome não pode ser vazio." && continue
  break
done

# Prompt para usuário de acesso
while true; do
  prompt "Digite o NOME do usuário para acesso ao compartilhamento (ex: smbuser):"
  read SMB_USER
  [[ -z "$SMB_USER" ]] && warn "Usuário não pode ser vazio." && continue
  break
done

# Criação do usuário de sistema se não existir
if ! id "$SMB_USER" &>/dev/null; then
  info "Usuário $SMB_USER não existe. Criando..."
  useradd -M -s /usr/sbin/nologin "$SMB_USER"
  ok "Usuário de sistema $SMB_USER criado."
else
  ok "Usuário de sistema $SMB_USER já existe."
fi

# Definir senha do usuário Samba
info "Defina a senha para o usuário Samba (será usada para acessar o compartilhamento na rede):"
smbpasswd -a "$SMB_USER"
smbpasswd -e "$SMB_USER"

# Permissões do diretório
chown -R "$SMB_USER":"$SMB_USER" "$DIR_SHARE"
chmod -R 770 "$DIR_SHARE"

# Backup do smb.conf
cp /etc/samba/smb.conf "/etc/samba/smb.conf.bak.$(date +%Y%m%d%H%M%S)"

# Adiciona configuração ao smb.conf
cat <<EOF >> /etc/samba/smb.conf

[$SHARE_NAME]
   path = $DIR_SHARE
   valid users = $SMB_USER
   read only = no
   browsable = yes
   guest ok = no
   force user = $SMB_USER
EOF

ok "Configuração adicionada ao smb.conf."

# Reinicia serviço
info "Reiniciando serviço Samba..."
systemctl restart smbd
if [[ $? -eq 0 ]]; then
  ok "Samba reiniciado com sucesso."
else
  error "Falha ao reiniciar o Samba. Verifique o status com: systemctl status smbd"
  exit 4
fi

echo -e "\n${GREEN}${emoji_ok} Compartilhamento criado com sucesso!${NC}"
echo -e "${CYAN}Acesse do Windows usando: \\$(hostname -I | awk '{print $1}')\\$SHARE_NAME${NC}"
echo -e "${YELLOW}Usuário: $SMB_USER${NC}"
echo -e "${YELLOW}Dica: Se necessário, libere as portas 445 e 139 no firewall (ufw).${NC}"
echo -e "${BLUE}Para desfazer, remova a entrada do smb.conf e reinicie o Samba.${NC}"