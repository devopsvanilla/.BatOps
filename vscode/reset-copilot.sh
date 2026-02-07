#!/usr/bin/env bash

set -e

echo "=============================================="
echo "   Reset seguro do GitHub Copilot no VS Code"
echo "   Ambiente: Ubuntu na WSL"
echo "=============================================="
echo
echo "1) Certifique-se de que o VS Code está FECHADO"
echo "   - Feche todas as janelas do VS Code no Windows."
echo "   - Aguarde alguns segundos."
echo
read -p "VS Code está fechado? [y/N] " ans
[[ "$ans" == "y" || "$ans" == "Y" ]] || { echo "Abortado."; exit 1; }

# Caminhos do VS Code/WSL (lado Linux)
CODE_CFG="$HOME/.vscode-server"
CODE_USER_DIR="$CODE_CFG/data/User"
COPILOT_GS="$CODE_USER_DIR/globalStorage/github.copilot"
COPILOT_CHAT_GS="$CODE_USER_DIR/globalStorage/github.copilot-chat"
CACHE_DIR="$CODE_CFG/data/CachedData"

echo
echo "2) Removendo somente dados do Copilot e cache relacionado no WSL..."
echo "   (não serão alteradas outras configurações e extensões)"

echo " - Limpando estado do GitHub Copilot:"
echo "   $COPILOT_GS"
rm -rf "$COPILOT_GS" 2>/dev/null || true

echo " - Limpando estado do GitHub Copilot Chat (se existir):"
echo "   $COPILOT_CHAT_GS"
rm -rf "$COPILOT_CHAT_GS" 2>/dev/null || true

echo " - Limpando cache do VS Code no WSL (CachedData):"
echo "   $CACHE_DIR"
rm -rf "$CACHE_DIR" 2>/dev/null || true

echo
echo "3) Opcional: desinstalar extensões do Copilot apenas no WSL"
echo "   (mantém todas as outras extensões intactas)"
echo

# Tenta listar extensões lado WSL; ignora erro se 'code' não estiver no PATH
if command -v code >/dev/null 2>&1; then
  echo "Extensões do Copilot instaladas (se houver):"
  code --list-extensions | grep -E 'github.copilot|github.copilot-chat' || echo "   (nenhuma encontrada)"
  echo
  read -p "Deseja desinstalar extensões do Copilot SOMENTE no WSL agora? [y/N] " rmext
  if [[ "$rmext" == "y" || "$rmext" == "Y" ]]; then
    echo "Desinstalando extensões do Copilot no WSL..."
    # Desinstala extensões se existirem
    code --uninstall-extension github.copilot 2>/dev/null || true
    code --uninstall-extension github.copilot-chat 2>/dev/null || true
  else
    echo "Pulando desinstalação automática das extensões."
  fi
else
  echo "Aviso: comando 'code' não encontrado no PATH do WSL."
  echo "Se você usa VS Code com Remote-WSL normalmente, isso não é um problema;"
  echo "apenas desinstale as extensões manualmente dentro do VS Code."
fi

echo
echo "4) Próximos passos DENTRO do VS Code (manual)"
echo "   Depois que este script terminar:"
echo
echo "   a) Abra o VS Code novamente (no Windows) e conecte-se ao WSL como de costume."
echo "   b) No VS Code, no canto inferior esquerdo, clique no ícone de Contas."
echo "      - Saia de qualquer conta GitHub logada (GitHub Authentication, Settings Sync etc.)."
echo "   c) Abra a Paleta de Comandos (Ctrl+Shift+P) e execute:"
echo "      - 'Sign out of GitHub'"
echo "      - 'Developer: Clear Authentication Session' e escolha 'github' / 'GitHub'."
echo "   d) Vá para a aba Extensões, procure por 'GitHub Copilot' e 'GitHub Copilot Chat':"
echo "      - Se ainda estiverem instaladas, desinstale-as."
echo
echo "5) No navegador (conta GitHub)"
echo "   a) Acesse: https://github.com/settings/applications"
echo "   b) Em 'Authorized OAuth Apps', remova 'GitHub Copilot' e 'Visual Studio Code' se quiser"
echo "      garantir um login totalmente novo com a conta correta."
echo
echo "6) Reinstalar e logar com a nova conta"
echo "   a) No VS Code, instale novamente 'GitHub Copilot' (e 'GitHub Copilot Chat', se quiser)."
echo "   b) Quando o VS Code abrir o navegador para login do GitHub:"
echo "      - Use o perfil de navegador com a CONTA CORRETA."
echo "      - Se precisar, saia da conta errada no GitHub antes e faça login na certa."
echo
echo "Concluído o reset seguro do Copilot no VS Code (lado WSL)."
echo "Suas outras configurações e extensões permanecem intactas."
echo
exit 0
