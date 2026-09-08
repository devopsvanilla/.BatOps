#Requires -Version 5.1
<#
.SYNOPSIS
    Configura o acesso Git para contribuir no Azure DevOps (Repos/PRs) a partir
    do terminal, do Visual Studio Code, do Antigravity e do Visual Studio 2022.
.DESCRIPTION
    Usa o Git Credential Manager (GCM), já incluso no Git for Windows, para
    autenticação. As configurações são escopadas por host
    (https://dev.azure.com e https://*.visualstudio.com) para não conflitar
    com credenciais já configuradas para o GitHub.
.PARAMETER Organization
    URL da organização padrão do Azure DevOps (ex.: https://dev.azure.com/minhaorg)
.PARAMETER Project
    Projeto padrão do Azure DevOps.
.EXAMPLE
    ./Configure-ADOAccess.ps1
.EXAMPLE
    ./Configure-ADOAccess.ps1 -Organization https://dev.azure.com/minhaorg -Project MeuProjeto
#>
[CmdletBinding()]
param(
    [string]$Organization,
    [string]$Project
)

$ErrorActionPreference = 'Stop'

$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    Write-Error "❌ Git não encontrado. Instale o Git for Windows antes de continuar."
    exit 1
}

# O Git for Windows já inclui o Git Credential Manager (GCM) por padrão.
$gcmVersion = git credential-manager --version 2>$null
if ($gcmVersion) {
    Write-Host "✅ Git Credential Manager disponível: $gcmVersion" -ForegroundColor Green
}
else {
    Write-Host "⚠️ Git Credential Manager não encontrado. Reinstale/atualize o Git for Windows:" -ForegroundColor Yellow
    Write-Host "   https://gitforwindows.org/ (ou 'winget install --id Git.Git')" -ForegroundColor Yellow
}

function Set-ScopedCredentialHelper {
    param([string]$UrlPattern)

    git config --global --unset-all "credential.$UrlPattern.helper" 2>$null
    git config --global --add "credential.$UrlPattern.helper" "manager"
    Write-Host "✅ Configurado credential.$UrlPattern.helper = manager" -ForegroundColor Green
}

Write-Host "⏳ Configurando helpers de credencial escopados para Azure DevOps..." -ForegroundColor Yellow
Set-ScopedCredentialHelper -UrlPattern "https://dev.azure.com"
Set-ScopedCredentialHelper -UrlPattern "https://*.visualstudio.com"

if ($Organization -or $Project) {
    Write-Host "⏳ Atualizando defaults do az devops..." -ForegroundColor Yellow
    $defaultArgs = @()
    if ($Organization) { $defaultArgs += "organization=$Organization" }
    if ($Project) { $defaultArgs += "project=$Project" }
    az devops configure --defaults @defaultArgs
    Write-Host "✅ Defaults do az devops atualizados." -ForegroundColor Green
}
else {
    Write-Host "ℹ️  Defaults atuais do az devops:" -ForegroundColor Cyan
    az devops configure -l 2>$null
}

Write-Host ""
Write-Host "✅ Configuração concluída. VS Code, Antigravity e Visual Studio 2022 reutilizam o" -ForegroundColor Cyan
Write-Host "   mesmo git config, então o acesso configurado aqui vale para todos eles." -ForegroundColor Cyan
Write-Host ""
Write-Host "Para testar, clone um repositório do seu projeto (abrirá o navegador" -ForegroundColor Cyan
Write-Host "para autenticação na primeira vez):" -ForegroundColor Cyan
Write-Host "   git clone https://dev.azure.com/SUA_ORG/SEU_PROJETO/_git/SEU_REPO" -ForegroundColor Cyan
