#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"

echo "======================================"
echo "  Teste do Script up.sh"
echo "======================================"
echo ""

[[ -f "$SCRIPT_DIR/up.sh" ]] || { echo "❌ ERRO: up.sh não encontrado"; exit 1; }
[[ -x "$SCRIPT_DIR/up.sh" ]] || { echo "ℹ️  Tornando up.sh executável"; chmod +x "$SCRIPT_DIR/up.sh"; }
[[ -f "$SCRIPT_DIR/.env-sample" ]] || { echo "❌ ERRO: .env-sample não encontrado"; exit 1; }
[[ -f "$SCRIPT_DIR/docker-compose.yml" ]] || { echo "❌ ERRO: docker-compose.yml não encontrado"; exit 1; }

command -v docker >/dev/null 2>&1 || { echo "❌ ERRO: Docker não instalado"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "❌ ERRO: docker compose v2 não disponível"; exit 1; }

echo "✅ Dependências verificadas"

CONTEXTS=$(docker context ls --format '{{.Name}} ({{if .Current}}atual{{else}}não atual{{end}})' | tr '\n' '\n')
echo "\nContextos disponíveis:\n$CONTEXTS"
echo "Contexto atual: $(docker context show 2>/dev/null || echo default)"

if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
    echo "⚠️  Arquivo .env não encontrado. Ele será criado a partir do .env-sample quando você executar ./up.sh"
else
    echo "✅ Arquivo .env encontrado"
fi

echo "\nTudo pronto! Execute ./up.sh para iniciar a implantação usando o contexto desejado."
