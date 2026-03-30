#!/usr/bin/env bash
# TODO: Revisar e adicionar set -euo pipefail — Issue #1

# Script para configurar kubectl no perfil do usuário
# - Copia kubeconfig do admin para o usuário
# - Define permissões corretas
# - Configura variáveis de ambiente
# - Testa a conexão
# Autor: DevOps Vanilla
# Data: 2026-03-06

set -e

echo "======================================"
echo "Kubernetes kubectl Configuration"
echo "======================================"
echo ""

# Verifica se está rodando como usuário normal
if [ "$EUID" -eq 0 ]; then 
    echo "ℹ️  Script rodando como root"
    echo "   Usando root user para configuração"
    TARGET_HOME="/root"
else
    TARGET_HOME="$HOME"
fi

# Verifica se o arquivo de configuração do master existe
if [ ! -f /etc/kubernetes/admin.conf ]; then
    echo "❌ Arquivo /etc/kubernetes/admin.conf não encontrado"
    echo "   Este script deve ser executado no MASTER node"
    echo "   Execute primeiro: sudo bash ./init-master.sh"
    exit 1
fi

# Verifica se kubectl está instalado
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl não encontrado. Execute primeiro:"
    echo "   sudo bash ./install-requirements.sh"
    exit 1
fi

echo "✓ Sistema validado"
echo ""

# Criar diretório .kube se não existir
echo "[1/4] Criando diretório ~/.kube..."
mkdir -p "$TARGET_HOME/.kube"
echo "✓ Diretório criado"

# Copiar o arquivo de configuração
echo "[2/4] Copiando kubeconfig..."
if [ "$EUID" -eq 0 ]; then
    cp -v /etc/kubernetes/admin.conf "$TARGET_HOME/.kube/config"
else
    sudo cp /etc/kubernetes/admin.conf "$TARGET_HOME/.kube/config"
fi
echo "✓ Arquivo copiado"

# Definir permissões corretas
echo "[3/4] Configurando permissões..."

# Aplicar permissões seguras ao kubeconfig
if [ "$EUID" -eq 0 ]; then
    # Rodando como root
    chmod 600 "$TARGET_HOME/.kube/config"
    echo "   chmod 600 $TARGET_HOME/.kube/config"
else
    # Rodando como usuário normal
    sudo chmod 600 "$TARGET_HOME/.kube/config"
    echo "   sudo chmod 600 $TARGET_HOME/.kube/config"
    
    # Ajustar ownership para o usuário atual
    sudo chown "$USER:$(id -g)" "$TARGET_HOME/.kube/config"
    echo "   sudo chown $USER:$(id -g) $TARGET_HOME/.kube/config"
fi

echo "✓ Permissões configuradas (rw-------, ninguém consegue ler)"

# Testar a conexão
echo "[4/4] Testando conexão com Kubernetes..."
export KUBECONFIG="$TARGET_HOME/.kube/config"

# Aguardar um pouco para garantir que kubectl está pronto
sleep 1

if kubectl cluster-info &>/dev/null; then
    echo "✓ Conexão estabelecida com sucesso"
    echo ""
    echo "Informações do cluster:"
    kubectl cluster-info | grep -E "Kubernetes master|control plane"
    echo ""
else
    echo "⚠️  Aviso: Não foi possível conectar ao cluster"
    echo "   Aguarde alguns segundos e tente novamente:"
    echo "   kubectl cluster-info"
fi

echo ""
echo "======================================"
echo "✓ kubectl configurado com sucesso!"
echo "======================================"
echo ""

# Informações adicionais
echo "📋 PRÓXIMAS ETAPAS:"
echo ""
echo "1️⃣  Seus comandos kubectl agora funcionam:"
echo "   kubectl get nodes"
echo "   kubectl get pods -n kube-system"
echo ""

# Guia de shell
echo "2️⃣  Atualize seu shell (se necessário):"

if [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_RC="$TARGET_HOME/.zshrc"
elif [[ "$SHELL" == *"fish"* ]]; then
    SHELL_RC="$TARGET_HOME/.config/fish/config.fish"
else
    SHELL_RC="$TARGET_HOME/.bashrc"
fi

# Verificar se KUBECONFIG já está no shell config
if grep -q "KUBECONFIG" "$SHELL_RC" 2>/dev/null; then
    echo "   ℹ️  KUBECONFIG já configurado em $SHELL_RC"
else
    echo ""
    read -p "   Deseja adicionar KUBECONFIG ao seu perfil shell? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        if [[ "$SHELL_RC" == *"fish"* ]]; then
            echo "set -gx KUBECONFIG $TARGET_HOME/.kube/config" >> "$SHELL_RC"
        else
            echo "export KUBECONFIG=$TARGET_HOME/.kube/config" >> "$SHELL_RC"
        fi
        echo "   ✓ Adicionado ao $SHELL_RC"
        echo "   Recarregue seu shell: exec \$SHELL"
    fi
fi

echo ""
echo "3️⃣  Verifique o acesso:"
echo "   kubectl auth can-i '*' '*'  # Mostra permissões"
echo ""

# Setup bash completion (se disponível)
echo "4️⃣  (Opcional) Instalar autocompletar:"
echo "   # Para bash:"
echo "   sudo kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null"
echo ""
echo "   # Para zsh:"
echo "   kubectl completion zsh >> ~/.zshrc"
echo ""

# Aviso de segurança
echo "🔐 AVISO DE SEGURANÇA:"
echo "   ✅ Arquivo kubeconfig protegido com chmod 600"
echo "   ⚠️  Contém credenciais de administrador do cluster"
echo "   ⚠️  Não compartilhe este arquivo nem via Git"
echo "   ⚠️  Se comprometido: regenere token de acesso"
echo ""

echo "======================================"
