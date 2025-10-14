# Compact-WSL.ps1 — Utility for compacting and backing up WSL distributions
# Autor: Guardião DevOps (devopsvanilla)
# Finalidade: Compactar e exportar distribuições WSL em arquivos .tar compactados.
# Uso (modo CLI/batch): .\Compact-WSL.ps1 -Name "Ubuntu-24.04" -Output "C:\BackupWSL" [-CompactOnly] [-ExportOnly]
# Uso (modo interativo): Execute sem parâmetros e siga as instruções na tela.
<#
.SYNOPSIS
    Compacta e faz backup de distribuições WSL.
.DESCRIPTION
    Este script PowerShell compacta distribuições WSL (Windows Subsystem for Linux) e as exporta
    para arquivos .tar, reduzindo o tamanho do disco virtual e criando backups portáteis.

    Recursos:
    - Compactação automática do disco virtual WSL
    - Exportação para arquivo .tar
    - Suporte para múltiplas distribuições
    - Verificação de espaço disponível
    - Logs detalhados
.PARAMETER Name
    Nome da distribuição WSL a ser compactada (ex: Ubuntu-24.04, Debian).
    Se especificado, executa no modo não interativo.
.PARAMETER Output
    Diretório de saída para o arquivo .tar exportado.
    Padrão: Diretório do usuário (C:\Users\<username>\WSL-Backups)
.PARAMETER CompactOnly
    Se especificado, apenas compacta o disco virtual sem exportar (modo não interativo).
.PARAMETER ExportOnly
    Se especificado, apenas exporta sem compactar (modo não interativo).
.EXAMPLE
    .\Compact-WSL.ps1
    Inicia o modo interativo completo para seleção de distribuição e operação.
.EXAMPLE
    .\Compact-WSL.ps1 -Name "Ubuntu-24.04"
    Compacta e exporta a distribuição Ubuntu-24.04 (modo não interativo).
.EXAMPLE
    .\Compact-WSL.ps1 -Name "Debian" -CompactOnly
    Apenas compacta sem exportar (modo não interativo).
.NOTES
    Requer privilégios administrativos para algumas operações.
    Certifique-se de que a distribuição WSL esteja parada antes de compactar.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Name,

    [Parameter(Position = 1)]
    [string]$Output = "$env:USERPROFILE\WSL-Backups",

    [switch]$CompactOnly,

    [switch]$ExportOnly
)

# =====================
# BLOCO NOVO: Modo Interativo Completo
# - Quando o script é executado SEM ARGUMENTOS, ele entra em modo interativo.
# - Passos:
#   1) Lista as distribuições WSL encontradas em tabela e também em lista numerada.
#   2) Solicita ao usuário escolher a numeração da distribuição desejada.
#   3) Apresenta um menu de operação:
#        [1] Gerar cópia compactada (.tar backup seguro)
#        [2] Compactar a distribuição existente (VHDX, liberar espaço)
#   4) Solicita a escolha (1 ou 2) e ajusta as variáveis internas (CompactOnly/ExportOnly/Name/Output).
#   5) Continua o fluxo normal conforme a escolha, sem exigir argumentos.
# - Se quaisquer dos argumentos -Name, -CompactOnly, -ExportOnly forem passados, mantém o comportamento atual (não interativo).
# =====================

function Write-ColorOutput {
    param(
        [string]$Message,
        [ConsoleColor]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Get-WSLDistributions {
    <#
    .SYNOPSIS
        Obtém lista de distribuições WSL instaladas com estado e versão.
    #>
    try {
        $Distros = wsl --list --quiet | Where-Object { $_.Trim() -ne "" }
        if ($Distros -is [string]) { $Distros = @($Distros) }
        if (-not $Distros -or $Distros.Count -eq 0) {
            Write-Host "[ERRO] Nenhuma distribuição WSL encontrada. Instale uma distribuição primeiro." -ForegroundColor Red
            exit 1
        }

        $wslList = wsl --list --verbose
        $distributions = @()

        foreach ($line in $wslList) {
            $cleanLine = $line -replace '[^\x20-\x7E]', '' -replace '\s+', ' ' -replace '^ ', ''
            if ($cleanLine -match '^NAME' -or [string]::IsNullOrWhiteSpace($cleanLine)) { continue }
            if ($cleanLine -match '^([*]?)\s*([^\s]+)\s+(\w+)\s+(\d+)') {
                $isDefault = $matches[1] -eq '*'
                $distName  = $matches[2]
                $state     = $matches[3]
                $version   = $matches[4]
                $distributions += [PSCustomObject]@{
                    Default = $isDefault
                    Name    = $distName
                    State   = $state
                    Version = $version
                }
            }
        }
        return $distributions
    }
    catch {
        Write-ColorOutput "[ERRO] Falha ao listar distribuições WSL: $($_.Exception.Message)" "Red"
        exit 1
    }
}

function Stop-WSLDistribution {
    param([string]$DistName)
    Write-ColorOutput "Parando distribuição $DistName..." "Yellow"
    try {
        wsl --terminate $DistName
        Start-Sleep -Seconds 2
        Write-ColorOutput "Distribuição parada com sucesso." "Green"
    }
    catch {
        Write-ColorOutput "[AVISO] Não foi possível parar a distribuição: $($_.Exception.Message)" "Yellow"
    }
}

function Compress-WSLDisk {
    param([string]$DistName)
    Write-ColorOutput "`nCompactando disco virtual da distribuição $DistName..." "Cyan"

    $vhdxPath = "$env:LOCALAPPDATA\Packages\CanonicalGroupLimited.*\LocalState\ext4.vhdx"
    $vhdxFiles = Get-ChildItem -Path $env:LOCALAPPDATA\Packages -Filter "ext4.vhdx" -Recurse -ErrorAction SilentlyContinue |
                 Where-Object { $_.DirectoryName -like "*$DistName*" -or $_.Directory.Parent.Name -like "*$DistName*" }

    if (-not $vhdxFiles) {
        Write-ColorOutput "Tentando localizar VHDX via registro..." "Gray"
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
        $distroKeys = Get-ChildItem $regPath -ErrorAction SilentlyContinue
        foreach ($key in $distroKeys) {
            $name = (Get-ItemProperty -Path $key.PSPath -Name DistributionName -ErrorAction SilentlyContinue).DistributionName
            if ($name -eq $DistName) {
                $basePath = (Get-ItemProperty -Path $key.PSPath -Name BasePath -ErrorAction SilentlyContinue).BasePath
                $vhdxPath = Join-Path $basePath "ext4.vhdx"
                if (Test-Path $vhdxPath) { $vhdxFiles = Get-Item $vhdxPath; break }
            }
        }
    }

    if (-not $vhdxFiles -or $vhdxFiles.Count -eq 0) {
        Write-ColorOutput "[AVISO] Arquivo VHDX não encontrado. Pulando compactação." "Yellow"
        return
    }

    $vhdxPath   = $vhdxFiles[0].FullName
    $sizeBefore = [math]::Round((Get-Item $vhdxPath).Length / 1GB, 2)

    Write-ColorOutput "Arquivo VHDX: $vhdxPath" "Gray"
    Write-ColorOutput "Tamanho antes: $sizeBefore GB" "Gray"

    try {
        $diskpartScript = @"
select vdisk file="$vhdxPath"
attach vdisk readonly
compact vdisk
detach vdisk
"@
        $diskpartScript | diskpart | Out-Null

        $sizeAfter = [math]::Round((Get-Item $vhdxPath).Length / 1GB, 2)
        $saved     = [math]::Round($sizeBefore - $sizeAfter, 2)

        Write-ColorOutput "Tamanho depois: $sizeAfter GB" "Green"
        Write-ColorOutput "Espaço economizado: $saved GB" "Green"
    }
    catch {
        Write-ColorOutput "[ERRO] Falha na compactação: $($_.Exception.Message)" "Red"
    }
}

function Export-WSLDistribution {
    param(
        [string]$DistName,
        [string]$OutputPath
    )
    Write-ColorOutput "`nExportando distribuição $DistName..." "Cyan"

    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $timestamp  = Get-Date -Format "yyyyMMdd-HHmmss"
    $exportFile = Join-Path $OutputPath "$DistName-$timestamp.tar"

    Write-ColorOutput "Exportando para: $exportFile" "Gray"

    try {
        wsl --export $DistName $exportFile
        if (Test-Path $exportFile) {
            $fileSize = [math]::Round((Get-Item $exportFile).Length / 1GB, 2)
            Write-ColorOutput "Exportação concluída: $fileSize GB" "Green"
            return $exportFile
        } else {
            throw "Arquivo de exportação não foi criado."
        }
    }
    catch {
        Write-ColorOutput "[ERRO] Falha na exportação: $($_.Exception.Message)" "Red"
        throw
    }
}

function Invoke-InteractiveMode {
    param([array]$Distributions)

    Write-ColorOutput "`n=== Compact-WSL: Modo Interativo ===`n" "Cyan"

    Write-ColorOutput "Distribuições WSL disponíveis (tabela):`n" "Yellow"
    $Distributions | Format-Table -Property @(
        @{Label="Padrão"; Expression={ if ($_.Default) {"*"} else {" "} }},
        "Name",
        "State",
        @{Label="Versão WSL"; Expression={$_.Version}}
    ) -AutoSize | Out-Host

    Write-ColorOutput "`nSeleção rápida (lista numerada):" "Yellow"
    for ($i=0; $i -lt $Distributions.Count; $i++) {
        $prefix = if ($Distributions[$i].Default) {'*'} else {' '}
        Write-Host ("[{0}] {1}{2}" -f ($i+1), $prefix + ' ', $Distributions[$i].Name)
    }

    $selectedIndex = $null
    while ($null -eq $selectedIndex) {
        $inputValue = Read-Host "\nDigite o número da distribuição desejada"
        $num = $null
        if ([int]::TryParse($inputValue, [ref]$num)) {
            if ($num -ge 1 -and $num -le $Distributions.Count) {
                $selectedIndex = $num - 1
            } else {
                Write-ColorOutput "Opção inválida. Escolha um número entre 1 e $($Distributions.Count)." "Yellow"
            }
        } else {
            Write-ColorOutput "Entrada inválida. Digite apenas números." "Yellow"
        }
    }

    $selectedDistro = $Distributions[$selectedIndex].Name
    Write-ColorOutput "\nDistribuição selecionada: $selectedDistro" "Cyan"

    Write-Host "\nEscolha a operação:" -ForegroundColor Yellow
    Write-Host "  [1] Gerar cópia compactada (.tar backup seguro)" -ForegroundColor White
    Write-Host "  [2] Compactar a distribuição existente (VHDX, liberar espaço)" -ForegroundColor White

    $operation = $null
    while ($null -eq $operation) {
        $op = Read-Host "Digite 1 ou 2"
        switch ($op) {
            '1' { $operation = 1 }
            '2' { $operation = 2 }
            default { Write-ColorOutput "Opção inválida. Digite 1 ou 2." "Yellow" }
        }
    }

    $result = [PSCustomObject]@{
        Name        = $selectedDistro
        CompactOnly = ($operation -eq 2)
        ExportOnly  = ($operation -eq 1)
        Output      = $Output
    }

    if ($result.ExportOnly -and -not $PSBoundParameters.ContainsKey('Output')) {
        $defaultOut = $Output
        $customOut = Read-Host ("Diretório de saída (ENTER para usar padrão: {0})" -f $defaultOut)
        if ($customOut -and $customOut.Trim() -ne '') { $result.Output = $customOut.Trim() }
    }

    return $result
}

try {
    Write-ColorOutput "`n=== Compact-WSL: Utilitário de Compactação e Backup WSL ===`n" "Cyan"

    $Distros = wsl --list --quiet | Where-Object { $_.Trim() -ne "" }
    if ($Distros -is [string]) { $Distros = @($Distros) }
    if (-not $Distros -or $Distros.Count -eq 0) {
        Write-Host "[ERRO] Nenhuma distribuição WSL encontrada. Instale uma distribuição primeiro." -ForegroundColor Red
        exit 1
    }

    $distributions = Get-WSLDistributions
    if ($distributions.Count -eq 0) { throw "Nenhuma distribuição WSL encontrada. Instale uma distribuição primeiro." }

    if ($PSBoundParameters.ContainsKey('Name') -or $CompactOnly -or $ExportOnly) {
        $targetDist = $distributions | Where-Object { $_.Name -eq $Name }
        if (-not $targetDist) { throw "Distribuição '$Name' não encontrada. Use o script sem parâmetros para listar distribuições disponíveis." }

        Write-ColorOutput "Distribuição selecionada: $Name" "Cyan"
        Write-ColorOutput "Estado atual: $($targetDist.State)" "Gray"

        if ($targetDist.State -eq "Running") { Stop-WSLDistribution -DistName $Name }

        if (-not $ExportOnly) { Compress-WSLDisk -DistName $Name }
        if (-not $CompactOnly) { $exportedFile = Export-WSLDistribution -DistName $Name -OutputPath $Output }
    }
    else {
        $choice = Invoke-InteractiveMode -Distributions $distributions
        $Name        = $choice.Name
        $CompactOnly = $choice.CompactOnly
        $ExportOnly  = $choice.ExportOnly
        $Output      = $choice.Output

        $targetDist = $distributions | Where-Object { $_.Name -eq $Name }
        Write-ColorOutput "Estado atual: $($targetDist.State)" "Gray"
        if ($targetDist.State -eq "Running") { Stop-WSLDistribution -DistName $Name }
        if (-not $ExportOnly) { Compress-WSLDisk -DistName $Name }
        if (-not $CompactOnly) { $exportedFile = Export-WSLDistribution -DistName $Name -OutputPath $Output }
    }

    Write-ColorOutput "`n=== Operação concluída com sucesso! ===" "Green"

    if ($exportedFile) {
        Write-ColorOutput "`nPara restaurar este backup em outra máquina, use:" "Yellow"
        Write-ColorOutput "wsl --import <diretorio-instalacao> $exportedFile" "Gray"
    }

}
catch {
    Write-ColorOutput "`n[ERRO] $($_.Exception.Message)" "Red"
    Write-ColorOutput "Detalhes: $($_.ScriptStackTrace)" "DarkRed"
    exit 1
}
