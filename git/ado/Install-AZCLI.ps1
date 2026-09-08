#Requires -Version 5.1
<#
.SYNOPSIS
    Instala (ou valida) o Azure CLI (az) e a extensão "azure-devops" no Windows.
.DESCRIPTION
    Necessário para trabalhar com repositórios, Pull Requests, Boards e
    Pipelines do Azure DevOps a partir do terminal, do Visual Studio Code,
    do Antigravity e do Visual Studio 2022.
.PARAMETER Force
    Força a (re)instalação nativa do Azure CLI sem perguntar, mesmo que já
    exista uma versão instalada.
.PARAMETER Yes
    Modo não interativo: aceita os valores padrão de cada confirmação sem
    perguntar (útil em automação/CI).
.EXAMPLE
    ./Install-AZCLI.ps1
.EXAMPLE
    ./Install-AZCLI.ps1 -Force
#>
[CmdletBinding()]
param(
    [switch]$Force,
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

function Install-AzureCli {
    Write-Host "⏳ Instalando Azure CLI..." -ForegroundColor Yellow
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        winget install --id Microsoft.AzureCLI --exact --silent --accept-package-agreements --accept-source-agreements
    }
    else {
        $installer = Join-Path $env:TEMP 'AzureCLI.msi'
        Invoke-WebRequest -Uri 'https://aka.ms/installazurecliwindows' -OutFile $installer
        Start-Process msiexec.exe -ArgumentList "/i `"$installer`" /qn" -Wait
        Remove-Item $installer -ErrorAction SilentlyContinue
    }
    Write-Host "✅ Azure CLI instalado. Pode ser necessário reabrir o terminal para atualizar o PATH." -ForegroundColor Green
}

$azCommand = Get-Command az -ErrorAction SilentlyContinue

if ($azCommand) {
    Write-Host "✅ Azure CLI já disponível em: $($azCommand.Source)" -ForegroundColor Green
    az version

    if ($Force) {
        Write-Host "⚠️ Reinstalação forçada solicitada (-Force)." -ForegroundColor Yellow
        Install-AzureCli
    }
    elseif (Confirm-Action -Question "Deseja reinstalar o Azure CLI mesmo assim?" -Default 'N') {
        Install-AzureCli
    }
    else {
        Write-Host "↪️  Mantendo a instalação atual do Azure CLI, sem alterações." -ForegroundColor Cyan
    }
}
else {
    Install-AzureCli
}

Write-Host "⏳ Verificando extensão 'azure-devops'..." -ForegroundColor Yellow
$hasExtension = Invoke-AzQuiet -ArgumentList @('extension', 'list', '--output', 'tsv', '--query', "[?name=='azure-devops'].name")
if ($hasExtension) {
    Write-Host "✅ Extensão 'azure-devops' já instalada." -ForegroundColor Green
    if (Confirm-Action -Question "Deseja atualizar a extensão 'azure-devops' para a última versão agora?" -Default 'S') {
        az extension update --name azure-devops --only-show-errors
        Write-Host "✅ Extensão atualizada." -ForegroundColor Green
    }
    else {
        Write-Host "↪️  Mantendo a versão atual da extensão." -ForegroundColor Cyan
    }
}
else {
    az extension add --name azure-devops --only-show-errors
    Write-Host "✅ Extensão 'azure-devops' instalada." -ForegroundColor Green
}

Write-Host ""
Write-Host "✅ Pronto! Próximos passos (são 2 comandos separados, execute um de cada vez):" -ForegroundColor Cyan
Write-Host "   1) Autentique-se:" -ForegroundColor Cyan
Write-Host "      az login" -ForegroundColor Cyan
Write-Host "   2) Configure os defaults do Azure DevOps (--defaults é opção do 'az devops configure', não do 'az login'):" -ForegroundColor Cyan
Write-Host "      az devops configure --defaults organization=https://dev.azure.com/SUA_ORG project=SEU_PROJETO" -ForegroundColor Cyan
Write-Host "   3) Rode ./Configure-ADOAccess.ps1 para preparar o acesso Git (terminal, VS Code, Antigravity e Visual Studio 2022)." -ForegroundColor Cyan
