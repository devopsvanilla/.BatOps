#!/bin/bash

###############################################################################
# Script: add-to-windows-hosts.sh
# Descrição: Adiciona portainer.local ao hosts do Windows (via WSL)
# Requer: Executar com privilégios de administrador no PowerShell
# Uso: bash add-to-windows-hosts.sh
###############################################################################

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PORTAINER_HOST="portainer.local"
PORTAINER_IP="127.0.0.1"

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Adicionar portainer.local ao Windows Hosts    ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
}

print_header

echo ""
echo -e "${BLUE}Opção 1: Adicionar via PowerShell (Recomendado)${NC}"
echo ""
echo "Execute o seguinte comando no PowerShell com privilégios de administrador:"
echo ""
echo -e "${YELLOW}# PowerShell (como Administrador)${NC}"
echo 'Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "`n127.0.0.1`t\tportainer.local" -Force'
echo ""
echo "Ou use este bloco inteiro:"
echo ""
cat << 'EOF'
# PowerShell (como Administrador)
$hostsPath = "C:\Windows\System32\drivers\etc\hosts"
$entry = "127.0.0.1`t`tportainer.local"

# Verificar se já existe
$content = Get-Content $hostsPath
if ($content -notcontains $entry) {
    Add-Content -Path $hostsPath -Value "`n$entry" -Force
    Write-Host "Entrada adicionada ao hosts!" -ForegroundColor Green
} else {
    Write-Host "Entrada já existe no hosts!" -ForegroundColor Yellow
}
EOF

echo ""
echo -e "${BLUE}Opção 2: Editar manualmente${NC}"
echo ""
echo "1. Abra Bloco de Notas como Administrador"
echo "2. Abra: C:\\Windows\\System32\\drivers\\etc\\hosts"
echo "3. Adicione a seguinte linha:"
echo "   $PORTAINER_IP    $PORTAINER_HOST"
echo "4. Salve o arquivo"
echo ""

echo -e "${BLUE}Opção 3: Usar script PowerShell (WSL → Windows)${NC}"
echo ""
echo "Salve este script como 'add-portainer-hosts.ps1' e execute como administrador:"
echo ""
cat << 'EOF'
# add-portainer-hosts.ps1
# Executar como Administrador
$hostsPath = "C:\Windows\System32\drivers\etc\hosts"
$hostEntry = "127.0.0.1`t`tportainer.local"

try {
    if (!(Test-Path $hostsPath)) {
        Write-Host "Arquivo hosts não encontrado!" -ForegroundColor Red
        exit 1
    }
    
    $content = @(Get-Content $hostsPath)
    
    if ($content -contains $hostEntry) {
        Write-Host "Entrada já existe!" -ForegroundColor Yellow
    } else {
        $content += $hostEntry
        $content | Set-Content $hostsPath
        Write-Host "Entrada adicionada com sucesso!" -ForegroundColor Green
        Write-Host "Acesse: https://portainer.local" -ForegroundColor Green
    }
} catch {
    Write-Host "Erro: $_" -ForegroundColor Red
    exit 1
}
EOF

echo ""
echo -e "${YELLOW}[!]${NC} IMPORTANTE:"
echo "    • Você precisará de privilégios de administrador no Windows"
echo "    • Após adicionar, pode levar alguns segundos para o DNS resolver"
echo "    • Teste com: ping portainer.local (no PowerShell/CMD)"
echo ""

echo -e "${BLUE}Após configurar o DNS:${NC}"
echo ""
echo "1. Inicie o Portainer:"
echo "   bash ./run-portainer.sh start"
echo ""
echo "2. Acesse: https://portainer.local"
echo ""
echo "3. Aceite o certificado auto-assinado no navegador"
echo ""
