<#
.SYNOPSIS
Reseta completamente a extensão GitHub Copilot no Visual Studio Code.

.DESCRIPTION
Este script automatiza o processo de redefinição da extensão GitHub Copilot no VS Code, incluindo:
- Encerramento do VS Code
- Remoção da extensão GitHub Copilot
- Exclusão de dados residuais da extensão
- Limpeza de credenciais salvas do GitHub (HTTPS)

Ideal para situações em que é necessário trocar a conta do Copilot sem afetar configurações Git locais.

.PARAMETER Nenhum
Este script não requer parâmetros. Ele opera diretamente no ambiente do usuário atual.

.EXAMPLE
.\Reset-GitHubCopilotVSCode.ps1

Executa o script e realiza a limpeza completa da extensão GitHub Copilot.

.NOTES
Autor: SeuNome
Data: 09/09/2025
Compatível com: Windows 10/11, PowerShell 5.1+
Versão: 1.0
#>

# Fecha o VS Code se estiver aberto
Write-Host "🔄 Fechando o Visual Studio Code..."
Get-Process "Code" -ErrorAction SilentlyContinue | Stop-Process -Force

# Caminhos relevantes
$vsCodeExtensionsPath = "$env:USERPROFILE\.vscode\extensions"
$copilotExtensionPattern = "github.copilot*"
$globalStoragePath = "$env:APPDATA\Code\User\globalStorage"
$copilotStoragePath = Join-Path $globalStoragePath "github.copilot"
$stateDbPath = Join-Path $globalStoragePath "state.vscdb"
$stateDbBackupPath = Join-Path $globalStoragePath "state.vscdb.backup"

# Remove a extensão GitHub Copilot
Write-Host "🧹 Removendo extensão GitHub Copilot..."
Get-ChildItem -Path $vsCodeExtensionsPath -Filter $copilotExtensionPattern -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force

# Remove dados residuais da extensão
Write-Host "🗑️ Removendo dados residuais do Copilot..."
if (Test-Path $copilotStoragePath) {
    Remove-Item -Path $copilotStoragePath -Recurse -Force
}

# Opcional: remove banco de dados de estado (pode afetar outras extensões)
Write-Host "🧨 Removendo banco de estado do VS Code (opcional)..."
if (Test-Path $stateDbPath) {
    Remove-Item -Path $stateDbPath -Force
}
if (Test-Path $stateDbBackupPath) {
    Remove-Item -Path $stateDbBackupPath -Force
}

# Limpa credenciais do GitHub (HTTPS)
Write-Host "🔐 Removendo credenciais salvas do GitHub..."
cmdkey /delete:git:https://github.com

Write-Host "`n✅ Limpeza concluída. Agora você pode abrir o VS Code e reinstalar o GitHub Copilot com outra conta."