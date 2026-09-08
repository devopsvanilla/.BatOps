#Requires -Version 5.1
<#
.SYNOPSIS
    Garante que o perfil global do Git (user.name e user.email) esteja
    configurado.
.DESCRIPTION
    Exigido para autoria correta de commits no Azure DevOps, GitHub ou
    qualquer outro provedor Git, tanto no terminal quanto no Visual Studio
    Code, no Antigravity e no Visual Studio 2022.
.PARAMETER Name
    Nome completo a ser usado nos commits.
.PARAMETER Email
    E-mail a ser usado nos commits.
.PARAMETER Force
    Sobrescreve valores já configurados, mesmo que já existam.
.EXAMPLE
    ./Set-GitProfile.ps1
.EXAMPLE
    ./Set-GitProfile.ps1 -Name "Sandro Cicero" -Email "sandro@exemplo.com" -Force
#>
[CmdletBinding()]
param(
    [string]$Name,
    [string]$Email,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    Write-Error "❌ Git não encontrado. Instale o Git for Windows antes de continuar."
    exit 1
}

$currentName = git config --global user.name 2>$null
$currentEmail = git config --global user.email 2>$null

if ($currentName -and $currentEmail -and -not $Force) {
    Write-Host "✅ Perfil Git já configurado:" -ForegroundColor Green
    Write-Host "   user.name  = $currentName"
    Write-Host "   user.email = $currentEmail"
    Write-Host "   (use -Force para alterar)"
    exit 0
}

if (-not $Name) {
    $Name = Read-Host "Nome completo para commits [$currentName]"
    if (-not $Name) { $Name = $currentName }
}

if (-not $Email) {
    $Email = Read-Host "E-mail para commits [$currentEmail]"
    if (-not $Email) { $Email = $currentEmail }
}

if (-not $Name -or -not $Email) {
    Write-Error "❌ Nome e e-mail são obrigatórios. Use -Name e -Email."
    exit 1
}

git config --global user.name "$Name"
git config --global user.email "$Email"

Write-Host "✅ Perfil Git configurado:" -ForegroundColor Green
Write-Host "   user.name  = $(git config --global user.name)"
Write-Host "   user.email = $(git config --global user.email)"
