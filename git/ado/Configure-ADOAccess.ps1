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
.PARAMETER Yes
    Modo não interativo: aceita os valores/padrões atuais sem perguntar
    (útil em automação/CI).
.EXAMPLE
    ./Configure-ADOAccess.ps1
.EXAMPLE
    ./Configure-ADOAccess.ps1 -Organization https://dev.azure.com/minhaorg -Project MeuProjeto
#>
[CmdletBinding()]
param(
    [string]$Organization,
    [string]$Project,
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

function Read-ValueWithDefault {
    param([string]$Question, [string]$DefaultValue)
    if ($Yes) { return $DefaultValue }
    $label = if ($DefaultValue) { $DefaultValue } else { 'nenhum' }
    $reply = Read-Host "$Question [$label]"
    if ([string]::IsNullOrWhiteSpace($reply)) { return $DefaultValue }
    return $reply
}

# Roda 'az' capturando stderr sem deixar $ErrorActionPreference='Stop' abortar o
# script (comum ao rodar de um caminho UNC do WSL, onde o az.cmd emite avisos).
function Invoke-AzQuiet {
    param([string[]]$ArgumentList)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        az @ArgumentList 2>$null
    }
    finally {
        $ErrorActionPreference = $prevEap
    }
}

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
    Write-Host "⚠️ Git Credential Manager não encontrado." -ForegroundColor Yellow
    if (Confirm-Action -Question "Deseja instalar/atualizar o Git for Windows agora (via winget) para obter o GCM?" -Default 'S') {
        $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            winget install --id Git.Git --exact --silent --accept-package-agreements --accept-source-agreements
            Write-Host "✅ Git for Windows instalado/atualizado. Reabra o terminal para atualizar o PATH." -ForegroundColor Green
        }
        else {
            Write-Host "❌ winget não encontrado. Instale manualmente: https://gitforwindows.org/" -ForegroundColor Red
        }
    }
    else {
        Write-Host "   Instale manualmente quando quiser: https://gitforwindows.org/" -ForegroundColor Cyan
    }
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
    $currentDefaults = Invoke-AzQuiet -ArgumentList @('devops', 'configure', '-l')
    $currentOrg = ($currentDefaults | Select-String -Pattern '^organization\s*=\s*(.+)$').Matches.Groups[1].Value
    $currentProject = ($currentDefaults | Select-String -Pattern '^project\s*=\s*(.+)$').Matches.Groups[1].Value

    $Organization = Read-ValueWithDefault -Question "Organização padrão do Azure DevOps (ex.: https://dev.azure.com/minhaorg)" -DefaultValue $currentOrg
    $Project = Read-ValueWithDefault -Question "Projeto padrão do Azure DevOps" -DefaultValue $currentProject

    if ($Organization -or $Project) {
        Write-Host "⏳ Atualizando defaults do az devops..." -ForegroundColor Yellow
        $defaultArgs = @()
        if ($Organization) { $defaultArgs += "organization=$Organization" }
        if ($Project) { $defaultArgs += "project=$Project" }
        az devops configure --defaults @defaultArgs
        Write-Host "✅ Defaults do az devops atualizados." -ForegroundColor Green
    }
    else {
        Write-Host "ℹ️  Nenhum default de organização/projeto configurado." -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "✅ Configuração concluída. VS Code, Antigravity e Visual Studio 2022 reutilizam o" -ForegroundColor Cyan
Write-Host "   mesmo git config, então o acesso configurado aqui vale para todos eles." -ForegroundColor Cyan
Write-Host ""
Write-Host "Para testar, clone um repositório do seu projeto (abrirá o navegador" -ForegroundColor Cyan
Write-Host "para autenticação na primeira vez):" -ForegroundColor Cyan
Write-Host "   git clone https://dev.azure.com/SUA_ORG/SEU_PROJETO/_git/SEU_REPO" -ForegroundColor Cyan
