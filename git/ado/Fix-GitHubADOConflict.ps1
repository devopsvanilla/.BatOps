#Requires -Version 5.1
<#
.SYNOPSIS
    Diagnostica (e opcionalmente corrige) conflitos entre o helper de
    credencial do GitHub CLI (gh) e o helper configurado para o Azure DevOps.
.DESCRIPTION
    Um "credential.helper" GLOBAL genérico (sem escopo de URL) é testado pelo
    Git para QUALQUER host, incluindo github.com, podendo conflitar com o
    helper escopado usado pelo 'gh' e quebrar a autenticação com o GitHub.
    Este script identifica esse cenário e, com -Fix, corrige mantendo backup.
.PARAMETER Fix
    Corrige automaticamente sem perguntar (faz backup do arquivo de config
    global do Git antes de alterar).
.PARAMETER Yes
    Modo não interativo: se um conflito for encontrado e -Fix não for
    informado, assume "não corrigir" (apenas diagnostica).
.EXAMPLE
    ./Fix-GitHubADOConflict.ps1
.EXAMPLE
    ./Fix-GitHubADOConflict.ps1 -Fix
#>
[CmdletBinding()]
param(
    [switch]$Fix,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'

function Confirm-Action {
    param(
        [string]$Question,
        [ValidateSet('S', 'N')]
        [string]$Default = 'S'
    )
    if ($Yes) { return $Default -eq 'S' }
    $suffix = if ($Default -eq 'N') { '[s/N]' } else { '[S/n]' }
    $reply = Read-Host "$Question $suffix"
    if ([string]::IsNullOrWhiteSpace($reply)) { $reply = $Default }
    return $reply -match '^[Ss]'
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "❌ Git não encontrado."
    exit 1
}

Write-Host "🔎 Analisando configuração global de credenciais do Git..." -ForegroundColor Cyan
Write-Host ""

$configList = git config --global --list 2>$null

$genericHelpers = $configList | Select-String -Pattern '^credential\.helper='
$scopedGithub = $configList | Select-String -Pattern '^credential\.https://(gist\.)?github\.com\.helper='
$scopedAdo = $configList | Select-String -Pattern '^credential\.https://(dev\.azure\.com|\*\.visualstudio\.com)\.helper='

Write-Host "Helpers escopados para GitHub:"
if ($scopedGithub) {
    $scopedGithub | ForEach-Object { Write-Host "  ✅ $_" }
}
else {
    Write-Host "  ⚠️ Nenhum encontrado (rode: gh auth setup-git)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Helpers escopados para Azure DevOps:"
if ($scopedAdo) {
    $scopedAdo | ForEach-Object { Write-Host "  ✅ $_" }
}
else {
    Write-Host "  ⚠️ Nenhum encontrado (rode: ./Configure-ADOAccess.ps1)" -ForegroundColor Yellow
}

Write-Host ""
$conflict = $false
if ($genericHelpers) {
    $conflict = $true
    Write-Host "⚠️ Encontrado(s) credential.helper GLOBAL genérico(s) (sem escopo de URL):" -ForegroundColor Yellow
    $genericHelpers | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
    Write-Host "   Isso pode ser testado pelo Git também para github.com e causar" -ForegroundColor Yellow
    Write-Host "   prompts inesperados ou substituir o helper do 'gh'." -ForegroundColor Yellow
}
else {
    Write-Host "✅ Nenhum credential.helper genérico encontrado. Sem conflito de escopo detectado." -ForegroundColor Green
}

Write-Host ""

if ($conflict) {
    if ($Fix -or (Confirm-Action -Question "Deseja corrigir agora (remove helpers genéricos, com backup do .gitconfig)?" -Default 'N')) {
        $gitConfigPath = Join-Path $HOME ".gitconfig"
        $backup = "$gitConfigPath.bak-$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item $gitConfigPath $backup
        Write-Host "🛟 Backup criado em: $backup" -ForegroundColor Cyan

        Write-Host "🛠️  Removendo credential.helper genérico(s)..." -ForegroundColor Yellow
        git config --global --unset-all credential.helper 2>$null

        Write-Host "🛠️  Reafirmando helper escopado do GitHub (via gh)..." -ForegroundColor Yellow
        if (Get-Command gh -ErrorAction SilentlyContinue) {
            gh auth setup-git
        }
        else {
            Write-Host "  ⚠️ 'gh' não encontrado no PATH; configure manualmente o helper do GitHub." -ForegroundColor Yellow
        }

        Write-Host "🛠️  Reafirmando helpers escopados do Azure DevOps..." -ForegroundColor Yellow
        git config --global --unset-all "credential.https://dev.azure.com.helper" 2>$null
        git config --global --add "credential.https://dev.azure.com.helper" "manager"
        git config --global --unset-all "credential.https://*.visualstudio.com.helper" 2>$null
        git config --global --add "credential.https://*.visualstudio.com.helper" "manager"

        Write-Host ""
        Write-Host "✅ Conflito corrigido. Configuração final relevante:" -ForegroundColor Green
        git config --global --list | Select-String -Pattern '^credential\.' | ForEach-Object { Write-Host "  $_" }
    }
    else {
        Write-Host "ℹ️  Nenhuma alteração feita. Rode novamente (ou responda 's' ao prompt, ou use '-Fix') para corrigir." -ForegroundColor Cyan
        exit 1
    }
}
else {
    exit 0
}
