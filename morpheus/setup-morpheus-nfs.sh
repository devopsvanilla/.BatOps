#!/usr/bin/env bash
# TODO: Revisar e adicionar set -euo pipefail — Issue #1

# ===========================================
# Script: setup-morpheus-nfs.sh
# Função: Configurar NFS para uso do Morpheus Data Enterprise com armazenamento local
# Parâmetros:
#   --directory <path> : Diretório para exportação NFS (default: /opt/morpheus/storage/virtual-images)
#   --subnet <cidr>   : Sub-rede para acesso NFS (default: 192.168.0.0/24)
#
# Procedimento pós-instalação:
#   - Verificar se a montagem está funcionando corretamente no cliente Morpheus
#   - Configurar o storage no Morpheus Data Enterprise apontando para o NFS configurado
# ===========================================

# Cores para saída
GREEN='[0;32m'
NC='[0m' # No Color

# Emojis
SUCCESS="â"
WARNING="â "
INFO="ð"

# Valores padrão
DIR_TO_EXPORT="/opt/morpheus/storage/virtual-images"
NETWORK_SUBNET="192.168.0.0/24"

show_help() {
  echo -e "${INFO} Uso: $0 [--directory <diretório>] [--subnet <sub-rede>]

Parâmetros opcinais:
  --directory : Diretório local para exportar via NFS (padrão: /opt/morpheus/storage/virtual-images)
  --subnet   : Sub-rede para permitir acesso NFS (padrão: 192.168.0.0/24)
"
  exit 1
}

# Ler parâmetros
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --directory)
      DIR_TO_EXPORT="$2"
      shift 2
      ;;
    --subnet)
      NETWORK_SUBNET="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      ;;
    *)
      echo -e "${WARNING} Parâmetro desconhecido: $1${NC}"
      show_help
      ;;
  esac
done

function install_package() {
  PKG_NAME=$1
  if dpkg -s "$PKG_NAME" &> /dev/null; then
    echo -e "${GREEN}${SUCCESS} Pacote $PKG_NAME já instalado.${NC}"
  else
    echo -e "${INFO} Instalando pacote $PKG_NAME...${NC}"
    sudo apt-get update -qq
    sudo apt-get install -y "$PKG_NAME"
    echo -e "${GREEN}${SUCCESS} Pacote $PKG_NAME instalado com sucesso.${NC}"
  fi
}

# Instalar dependências necessárias
install_package rpcbind
install_package nfs-kernel-server

# Criar diretório e definir permissões
if [ ! -d "$DIR_TO_EXPORT" ]; then
  echo -e "${INFO} Criando diretório $DIR_TO_EXPORT...${NC}"
  sudo mkdir -p "$DIR_TO_EXPORT"
else
  echo -e "${GREEN}${SUCCESS} Diretório $DIR_TO_EXPORT já existe.${NC}"
fi

echo -e "${INFO} Definindo permissões para o diretório $DIR_TO_EXPORT...${NC}"
sudo chown -R nobody:nogroup "$DIR_TO_EXPORT"
sudo chmod -R 755 "$DIR_TO_EXPORT"

# Remover configuração antiga no /etc/exports
sudo sed -i "/$DIR_TO_EXPORT/d" /etc/exports

# Adicionar linha de exportação no /etc/exports
export_line="$DIR_TO_EXPORT $NETWORK_SUBNET(rw,sync,no_subtree_check,no_root_squash,insecure)"
echo -e "${INFO} Adicionando exportação NFS: $export_line${NC}"
sudo bash -c "echo '$export_line' >> /etc/exports"

# Aplicar as exportações
echo -e "${INFO} Aplicando exportações NFS...${NC}"
sudo exportfs -ra

# Reiniciar serviços
echo -e "${INFO} Reiniciando serviços rpcbind e nfs-kernel-server...${NC}"
sudo systemctl restart rpcbind
sudo systemctl restart nfs-kernel-server

# Habilitar serviços
echo -e "${INFO} Habilitando serviços para iniciarem no boot...${NC}"
sudo systemctl enable rpcbind
sudo systemctl enable nfs-kernel-server

# Verificar status
sudo systemctl status rpcbind --no-pager | head -10
sudo systemctl status nfs-kernel-server --no-pager | head -10

# Exibir mensagem final

cat <<EOF

${GREEN}${SUCCESS} Configuração NFS concluída com sucesso!${NC}

Diretório exportado: $DIR_TO_EXPORT
Sub-rede permitida: $NETWORK_SUBNET

Agora, configure o Morpheus Data Enterprise para apontar este compartilhamento NFS como storage local.

Procedimento de pós-instalação:
1. No servidor cliente Morpheus, teste montar o NFS com:
     sudo mount -t nfs -o vers=3 <IP-DO-SERVIDOR>:$DIR_TO_EXPORT /ponto/de/montagem/teste
2. Após validação, configure o armazenamento no painel do Morpheus apontando para este NFS.

EOF
