#!/bin/bash

# Script de teste para validar funcionamento do up.sh
# em contextos locais e remotos

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================"
echo "  Teste do Script up.sh"
echo "======================================"
echo ""

# Verificar se o script existe
if [ ! -f "$SCRIPT_DIR/up.sh" ]; then
    echo "❌ ERRO: up.sh não encontrado!"
    exit 1
fi

echo "✅ Script up.sh encontrado"

# Verificar se é executável
if [ ! -x "$SCRIPT_DIR/up.sh" ]; then
    echo "⚠️  Script não é executável. Tornando executável..."
    chmod +x "$SCRIPT_DIR/up.sh"
fi

echo "✅ Script é executável"

# Verificar arquivo .env-sample
if [ ! -f "$SCRIPT_DIR/.env-sample" ]; then
    echo "❌ ERRO: .env-sample não encontrado!"
    exit 1
fi

echo "✅ Arquivo .env-sample encontrado"

# Verificar docker-compose.yml
if [ ! -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    echo "❌ ERRO: docker-compose.yml não encontrado!"
    exit 1
fi

echo "✅ Arquivo docker-compose.yml encontrado"

# Verificar se Docker está disponível
if ! command -v docker &> /dev/null; then
    echo "❌ ERRO: Docker não está instalado ou não está no PATH"
    exit 1
fi

echo "✅ Docker está disponível"

# Verificar se Docker Compose está disponível
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ ERRO: Docker Compose não está instalado"
    exit 1
fi

echo "✅ Docker Compose está disponível"

# Verificar contexto Docker atual
CURRENT_CONTEXT=$(docker context show 2>/dev/null || echo "default")
echo "ℹ️  Contexto Docker atual: $CURRENT_CONTEXT"

# Verificar endpoint do contexto
ENDPOINT=$(docker context inspect "$CURRENT_CONTEXT" --format '{{.Endpoints.docker.Host}}' 2>/dev/null || echo "")

if [[ "$ENDPOINT" == "unix://"* ]] || [[ -z "$ENDPOINT" ]]; then
    echo "ℹ️  Tipo de contexto: LOCAL"
    IS_REMOTE=false
elif [[ "$ENDPOINT" == "ssh://"* ]]; then
    echo "ℹ️  Tipo de contexto: REMOTO (SSH)"
    echo "ℹ️  Endpoint: $ENDPOINT"
    IS_REMOTE=true
    
    # Extrair informações SSH
    SSH_PART="${ENDPOINT#ssh://}"
    if [[ "$SSH_PART" == *"@"* ]]; then
        REMOTE_USER="${SSH_PART%%@*}"
        REMOTE_HOST="${SSH_PART#*@}"
        REMOTE_HOST="${REMOTE_HOST%%:*}"
    else
        REMOTE_USER="$(whoami)"
        REMOTE_HOST="$SSH_PART"
        REMOTE_HOST="${REMOTE_HOST%%:*}"
    fi
    
    echo "ℹ️  Host remoto: ${REMOTE_USER}@${REMOTE_HOST}"
    
    # Testar conectividade SSH
    echo ""
    echo "Testando conectividade SSH..."
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "${REMOTE_USER}@${REMOTE_HOST}" "echo 'Conexão SSH OK'" 2>/dev/null; then
        echo "✅ Conexão SSH funcionando"
    else
        echo "❌ ERRO: Não foi possível conectar via SSH"
        echo "   Verifique:"
        echo "   - Chave SSH configurada: ssh-copy-id ${REMOTE_USER}@${REMOTE_HOST}"
        echo "   - Conectividade de rede"
        exit 1
    fi
    
    # Verificar se Docker está disponível no host remoto
    echo ""
    echo "Verificando Docker no host remoto..."
    if ssh "${REMOTE_USER}@${REMOTE_HOST}" "docker --version" &>/dev/null; then
        REMOTE_DOCKER_VERSION=$(ssh "${REMOTE_USER}@${REMOTE_HOST}" "docker --version")
        echo "✅ Docker disponível no host remoto: $REMOTE_DOCKER_VERSION"
    else
        echo "❌ ERRO: Docker não está disponível no host remoto"
        exit 1
    fi
else
    echo "ℹ️  Tipo de contexto: REMOTO (Outro)"
    echo "ℹ️  Endpoint: $ENDPOINT"
    IS_REMOTE=true
fi

# Verificar se .env existe
echo ""
if [ -f "$SCRIPT_DIR/.env" ]; then
    echo "✅ Arquivo .env já existe"
    echo "⚠️  O script usará as configurações existentes"
else
    echo "⚠️  Arquivo .env não encontrado"
    echo "ℹ️  O script solicitará criação do .env a partir do .env-sample"
fi

# Verificar redes Docker disponíveis
echo ""
echo "Redes Docker disponíveis:"
docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | head -n 10

echo ""
echo "======================================"
echo "  Resumo do Teste"
echo "======================================"
echo ""
echo "✅ Todos os pré-requisitos estão atendidos"
echo ""

if [ "$IS_REMOTE" = true ]; then
    echo "📝 CONTEXTO REMOTO DETECTADO"
    echo ""
    echo "O script up.sh irá:"
    echo "  1. Sincronizar arquivos com o servidor remoto"
    echo "  2. Listar redes Docker do servidor remoto"
    echo "  3. Executar docker-compose no servidor remoto"
    echo "  4. Exibir URLs de acesso ao servidor remoto"
    echo ""
    if [ -n "$REMOTE_HOST" ]; then
        echo "URLs de acesso após execução:"
        echo "  - SQLPad: http://${REMOTE_HOST}:3000"
        echo "  - SQL Server: ${REMOTE_HOST}:1433"
    fi
else
    echo "📝 CONTEXTO LOCAL DETECTADO"
    echo ""
    echo "O script up.sh irá:"
    echo "  1. Listar redes Docker locais"
    echo "  2. Executar docker-compose localmente"
    echo "  3. Exibir URLs de acesso locais"
    echo ""
    echo "URLs de acesso após execução:"
    echo "  - SQLPad: http://localhost:3000"
    echo "  - SQL Server: localhost:1433"
fi

echo ""
echo "======================================"
echo ""
echo "Para executar o script, use:"
echo "  cd $SCRIPT_DIR"
echo "  ./up.sh"
echo ""

if [ "$IS_REMOTE" = true ]; then
    echo "💡 DICA: Se você não quer usar o contexto remoto, volte ao contexto local:"
    echo "  docker context use default"
    echo ""
fi

exit 0
