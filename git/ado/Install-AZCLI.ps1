#Requires -Version 5.1
<#
.SYNOPSIS
    Instala (ou valida) o Azure CLI (az) e a extensão "azure-devops" no Windows.
.DESCRIPTION
    Necessário para trabalhar com repositórios, Pull Requests, Boards e
    Pipelines do Azure DevOps a partir do terminal, do Visual Studio Code,
    do Antigravity e do Visual Studio 2022.
.PARAMETER Force
    Força a (re)instalação do Azure CLI mesmo que já exista uma versão instalada.
.EXAMPLE
    ./Install-AZCLI.ps1
.EXAMPLE
    ./Install-AZCLI.ps1 -Force
#>
[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$azCommand = Get-Command az -ErrorAction SilentlyContinue

if ($azCommand -and -not $Force) {
    Write-Host "✅ Azure CLI já disponível em: $($azCommand.Source)" -ForegroundColor Green
    az version
}
else {
    if ($azCommand -and $Force) {
        Write-Host "⚠️ Reinstalação forçada solicitada, prosseguindo mesmo com az já disponível em $($azCommand.Source)." -ForegroundColor Yellow
    }

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

Write-Host "⏳ Verificando extensão 'azure-devops'..." -ForegroundColor Yellow
$hasExtension = az extension list --output tsv --query "[?name=='azure-devops'].name" 2>$null
if ($hasExtension) {
    Write-Host "✅ Extensão 'azure-devops' já instalada. Atualizando..." -ForegroundColor Green
    az extension update --name azure-devops --only-show-errors
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
