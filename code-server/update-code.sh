#!/usr/bin/env bash
# TODO: Revisar e adicionar set -euo pipefail — Issue #1

set -e

# 🧠 Função para obter a última versão do GitHub
get_latest_version() {
  curl -s https://api.github.com/repos/coder/code-server/releases/latest | grep tag_name | cut -d '"' -f4
}

# 📦 Variáveis
LATEST_VERSION=$(get_latest_version)
ARCHIVE="code-server-$LATEST_VERSION-linux-amd64.tar.gz"
FOLDER="code-server-$LATEST_VERSION-linux-amd64"
INSTALL_DIR="/usr/lib/code-server"
BIN_LINK="/usr/bin/code-server"
BACKUP_DIR="$HOME/code-server-backup-$(date +%Y%m%d-%H%M%S)"

echo "🔍 Última versão encontrada: $LATEST_VERSION"

# 📁 Backup de configurações e extensões
echo "📦 Fazendo backup das configurações..."
mkdir -p "$BACKUP_DIR"
cp -r ~/.config/code-server "$BACKUP_DIR/config"
cp -r ~/.local/share/code-server "$BACKUP_DIR/share"

# 🔥 Remover versão anterior
echo "🧹 Removendo versão anterior..."
sudo rm -rf "$INSTALL_DIR"

# ⬇️ Baixar e extrair nova versão
echo "⬇️ Baixando $LATEST_VERSION..."
curl -fL "https://github.com/coder/code-server/releases/download/$LATEST_VERSION/$ARCHIVE" -o code-server.tar.gz
tar -xzf code-server.tar.gz

# 🚚 Mover nova versão
echo "🚚 Instalando nova versão..."
sudo mv "$FOLDER" "$INSTALL_DIR"

# 🔗 Atualizar link simbólico
echo "🔗 Atualizando link simbólico..."
sudo ln -sf "$INSTALL_DIR/bin/code-server" "$BIN_LINK"

# 🔁 Reiniciar serviço se existir
if systemctl list-units --type=service | grep -q code-server; then
  echo "🔁 Reiniciando serviço code-server..."
  sudo systemctl restart code-server
else
  echo "⚠️ Serviço systemd não encontrado. Execute manualmente: code-server"
fi

# ✅ Verificar versão instalada
echo "✅ Versão instalada:"
code-server --version