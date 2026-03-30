#!/usr/bin/env bash
# TODO: Revisar e adicionar set -euo pipefail — Issue #1

# Script para adicionar um novo worker node ao cluster Kubernetes
# - Gera um novo token a cada execução
# - Token NÃO é salvo em arquivo (segurança)
# - Exibe comando pronto para copiar/colar
# Autor: DevOps Vanilla
# Data: 2026-03-06

set -e

echo "======================================"
echo "Kubernetes Worker Node Addition"
echo "======================================"
echo ""

# Verifica se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Este script deve ser executado como root ou com sudo"
    echo "   Execute: sudo bash ./add-worker.sh"
    exit 1
fi

# Verifica se kubeadm está instalado
if ! command -v kubeadm &> /dev/null; then
    echo "❌ kubeadm não encontrado. Execute primeiro:"
    echo "   sudo bash ./install-requirements.sh"
    exit 1
fi

# Verifica se o master foi inicializado
if [ ! -f /etc/kubernetes/admin.conf ]; then
    echo "❌ Kubernetes não foi inicializado neste node."
    echo "   Execute primeiro: sudo bash ./init-master.sh"
    exit 1
fi

# Verifica se kubectl está disponível
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl não encontrado. Verifique a instalação."
    exit 1
fi

echo "✓ Sistema validado como Kubernetes Master"
echo ""

# Gera novo token (válido por 24 horas)
echo "[1/3] Gerando novo token de autenticação..."
JOIN_COMMAND=$(kubeadm token create --print-join-command 2>/dev/null)

if [ -z "$JOIN_COMMAND" ]; then
    echo "❌ Erro ao gerar token. Verifique se é root."
    exit 1
fi

TOKEN=$(echo "$JOIN_COMMAND" | awk '{print $5}')
MASTER_IP=$(echo "$JOIN_COMMAND" | awk '{print $3}' | cut -d: -f1)

echo "✓ Token gerado com sucesso"
echo "  Token válido por: 24 horas"
echo ""

# Extrai informações
echo "[2/3] Validando informações do cluster..."
HASH=$(kubeadm token create --print-join-command 2>/dev/null | grep -oP 'sha256:\K[a-f0-9]+')
echo "✓ Cluster validado"
echo "  Master: $MASTER_IP:6443"
echo ""

echo "[3/3] Preparando instruções para o worker..."
echo ""

# Exibe o comando de forma clara
echo "========================================"
echo "COPIE O COMANDO ABAIXO NO NODE WORKER:"
echo "========================================"
echo ""
echo "$JOIN_COMMAND"
echo ""
echo "========================================"
echo ""

# Instruções de execução
echo "📋 PRÓXIMAS ETAPAS:"
echo ""
echo "1️⃣  No node WORKER (como root ou sudo):"
echo "   sudo bash -c '$JOIN_COMMAND'"
echo ""
echo "2️⃣  Aguarde a conexão ser estabelecida (~10-30 segundos)"
echo ""
echo "3️⃣  No MASTER, verifique se o worker foi adicionado:"
echo "   kubectl get nodes"
echo ""

# Aviso de segurança
echo "🔐 AVISO DE SEGURANÇA:"
echo "   ⚠️  Este token NÃO foi salvo em nenhum arquivo"
echo "   ⚠️  Válido por 24 horas apenas"
echo "   ⚠️  Use ou descarte, nunca será reutilizado"
echo ""

# Opção de copiar para clipboard (se xclip estiver disponível)
if command -v xclip &> /dev/null; then
    echo "📋 COPIAR AUTOMATICAMENTE:"
    read -p "   Deseja copiar o comando para clipboard? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        echo "$JOIN_COMMAND" | xclip -selection clipboard
        echo "   ✓ Comando copiado! Cole no worker com: Ctrl+Shift+V ou Ctrl+V"
    fi
fi

echo ""
echo "======================================"
echo "✓ Instruções geradas com segurança"
echo "======================================"
echo ""
