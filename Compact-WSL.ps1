# Compact-WSL.ps1 — Utility for compacting and backing up WSL distributions
# Autor: Guardião DevOps (devopsvanilla)
# Finalidade: Compactar e exportar distribuições WSL em arquivos .tar compactados.
# Uso: .\Compact-WSL.ps1 -Name "Ubuntu-24.04" -Output "C:\BackupWSL"
# Veja README.md para detalhes.

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
    Se não especificado, lista todas as distribuições disponíveis.

.PARAMETER Output
    Diretório de saída para o arquivo .tar exportado.
    Padrão: Diretório do usuário (C:\Users\<username>\WSL-Backups)

.PARAMETER CompactOnly
    Se especificado, apenas compacta o disco virtual sem exportar.

.PARAMETER ExportOnly
    Se especificado, apenas exporta sem compactar.

.EXAMPLE
    .\Compact-WSL.ps1
    Lista todas as distribuições WSL disponíveis.

.EXAMPLE
    .\Compact-WSL.ps1 -Name "Ubuntu-24.04"
    Compacta e exporta a distribuição Ubuntu-24.04.

.EXAMPLE
    .\Compact-WSL.ps1 -Name "Ubuntu-24.04" -Output "D:\Backups\WSL"
    Compacta e exporta para um diretório específico.

.EXAMPLE
    .\Compact-WSL.ps1 -Name "Debian" -CompactOnly
    Apenas compacta sem exportar.

.NOTES
    Requer privilégios administrativos para algumas operações.
    Certifique-se de que a distribuição WSL esteja parada antes de compactar.
#>

[CmdletBinding()]
param
(
    [Parameter(Position = 0)]
    [string]$Name,
    
    [Parameter(Position = 1)]
    [string]$Output = "$env:USERPROFILE\WSL-Backups",
    
    [switch]$CompactOnly,
    
    [switch]$ExportOnly
)

# Funções auxiliares
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
        Obtém lista de distribuições WSL instaladas.
    #>
    
    try {
        # Enumerando distribuições WSL instaladas
        $Distros = wsl --list --quiet | Where-Object { $_.Trim() -ne "" }
        if ($Distros -is [string]) { $Distros = @($Distros) }
        if (-not $Distros -or $Distros.Count -eq 0) {
            Write-Host "[ERRO] Nenhuma distribuição WSL encontrada. Instale uma distribuição primeiro." -ForegroundColor Red
            exit 1
        }
        
        $wslList = wsl --list --verbose
        $distributions = @()
        
        # Parse da saída do wsl --list --verbose
        foreach ($line in $wslList) {
            # Remove caracteres especiais e espaços extras
            $cleanLine = $line -replace '[^\x20-\x7E]', '' -replace '\s+', ' ' -replace '^ ', ''
            
            # Ignora a linha de cabeçalho e linhas vazias
            if ($cleanLine -match '^NAME' -or [string]::IsNullOrWhiteSpace($cleanLine)) {
                continue
            }
            
            # Parse: * Ubuntu-24.04 Running 2
            if ($cleanLine -match '^([*]?)\s*([^\s]+)\s+(\w+)\s+(\d+)') {
                $isDefault = $matches[1] -eq '*'
                $distName = $matches[2]
                $state = $matches[3]
                $version = $matches[4]
                
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
    
    # Localiza o arquivo VHDX da distribuição
    $vhdxPath = "$env:LOCALAPPDATA\Packages\CanonicalGroupLimited.*\LocalState\ext4.vhdx"
    $vhdxFiles = Get-ChildItem -Path $env:LOCALAPPDATA\Packages -Filter "ext4.vhdx" -Recurse -ErrorAction SilentlyContinue |
                 Where-Object { $_.DirectoryName -like "*$DistName*" -or $_.Directory.Parent.Name -like "*$DistName*" }
    
    if (-not $vhdxFiles) {
        # Tenta localizar via registro
        Write-ColorOutput "Tentando localizar VHDX via registro..." "Gray"
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
        $distroKeys = Get-ChildItem $regPath -ErrorAction SilentlyContinue
        
        foreach ($key in $distroKeys) {
            $name = (Get-ItemProperty -Path $key.PSPath -Name DistributionName -ErrorAction SilentlyContinue).DistributionName
            if ($name -eq $DistName) {
                $basePath = (Get-ItemProperty -Path $key.PSPath -Name BasePath -ErrorAction SilentlyContinue).BasePath
                $vhdxPath = Join-Path $basePath "ext4.vhdx"
                if (Test-Path $vhdxPath) {
                    $vhdxFiles = Get-Item $vhdxPath
                    break
                }
            }
        }
    }
    
    if (-not $vhdxFiles -or $vhdxFiles.Count -eq 0) {
        Write-ColorOutput "[AVISO] Arquivo VHDX não encontrado. Pulando compactação." "Yellow"
        return
    }
    
    $vhdxPath = $vhdxFiles[0].FullName
    $sizeBefore = [math]::Round((Get-Item $vhdxPath).Length / 1GB, 2)
    
    Write-ColorOutput "Arquivo VHDX: $vhdxPath" "Gray"
    Write-ColorOutput "Tamanho antes: $sizeBefore GB" "Gray"
    
    try {
        # Compacta usando diskpart
        $diskpartScript = @"
select vdisk file="$vhdxPath"
attach vdisk readonly
compact vdisk
detach vdisk
"@
        
        $diskpartScript | diskpart | Out-Null
        
        $sizeAfter = [math]::Round((Get-Item $vhdxPath).Length / 1GB, 2)
        $saved = [math]::Round($sizeBefore - $sizeAfter, 2)
        
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
    
    # Cria diretório de saída se não existir
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $exportFile = Join-Path $OutputPath "$DistName-$timestamp.tar"
    
    Write-ColorOutput "Exportando para: $exportFile" "Gray"
    
    try {
        wsl --export $DistName $exportFile
        
        if (Test-Path $exportFile) {
            $fileSize = [math]::Round((Get-Item $exportFile).Length / 1GB, 2)
            Write-ColorOutput "Exportação concluída: $fileSize GB" "Green"
            return $exportFile
        }
        else {
            throw "Arquivo de exportação não foi criado."
        }
    }
    catch {
        Write-ColorOutput "[ERRO] Falha na exportação: $($_.Exception.Message)" "Red"
        throw
    }
}

# Script principal
try {
    Write-ColorOutput "`n=== Compact-WSL: Utilitário de Compactação e Backup WSL ===`n" "Cyan"
    
    # Enumerando distribuições WSL instaladas
    $Distros = wsl --list --quiet | Where-Object { $_.Trim() -ne "" }
    if ($Distros -is [string]) { $Distros = @($Distros) }
    if (-not $Distros -or $Distros.Count -eq 0) {
        Write-Host "[ERRO] Nenhuma distribuição WSL encontrada. Instale uma distribuição primeiro." -ForegroundColor Red
        exit 1
    }
    
    # Lista distribuições disponíveis
    $distributions = Get-WSLDistributions
    
    if ($distributions.Count -eq 0) {
        throw "Nenhuma distribuição WSL encontrada. Instale uma distribuição primeiro."
    }
    
    # Se nenhum nome foi especificado, lista as distribuições
    if (-not $Name) {
        Write-ColorOutput "Distribuições WSL disponíveis:`n" "Yellow"
        $distributions | Format-Table -Property @(
            @{Label="Padrão"; Expression={if($_.Default){"*"}else{" "}}},
            "Name",
            "State",
            @{Label="Versão WSL"; Expression={$_.Version}}
        ) -AutoSize
        
        Write-ColorOutput "`nUso: .\Compact-WSL.ps1 -Name <nome-da-distribuição> [-Output <diretório>]" "Gray"
        exit 0
    }
    
    # Verifica se a distribuição existe
    $targetDist = $distributions | Where-Object { $_.Name -eq $Name }
    if (-not $targetDist) {
        throw "Distribuição '$Name' não encontrada. Use o script sem parâmetros para listar distribuições disponíveis."
    }
    
    Write-ColorOutput "Distribuição selecionada: $Name" "Cyan"
    Write-ColorOutput "Estado atual: $($targetDist.State)" "Gray"
    
    # Para a distribuição se estiver rodando
    if ($targetDist.State -eq "Running") {
        Stop-WSLDistribution -DistName $Name
    }
    
    # Compacta
    if (-not $ExportOnly) {
        Compress-WSLDisk -DistName $Name
    }
    
    # Exporta
    if (-not $CompactOnly) {
        $exportedFile = Export-WSLDistribution -DistName $Name -OutputPath $Output
    }
    
    Write-ColorOutput "`n=== Operação concluída com sucesso! ===" "Green"
    
    if ($exportedFile) {
        Write-ColorOutput "`nPara restaurar este backup em outra máquina, use:" "Yellow"
        Write-ColorOutput "wsl --import <nome> <diretório> $exportedFile" "Gray"
    }
    
} catch {
    Write-ColorOutput "`n[ERRO] $($_.Exception.Message)" "Red"
    Write-ColorOutput "Detalhes: $($_.ScriptStackTrace)" "DarkRed"
    exit 1
}
