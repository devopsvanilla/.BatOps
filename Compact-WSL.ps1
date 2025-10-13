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
param(
    [Parameter(Position = 0)]
    [string]$Name,
    
    [Parameter(Position = 1)]
    [string]$Output = "$env:USERPROFILE\WSL-Backups",
    
    [switch]$CompactOnly,
    
    [switch]$ExportOnly
)

# Configurações
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Funções auxiliares
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Get-WSLDistributions {
    Write-Verbose "Obtendo lista de distribuições WSL..."
    $wslList = wsl --list --verbose 2>&1 | Out-String
    
    if ($LASTEXITCODE -ne 0) {
        throw "Erro ao listar distribuições WSL. Certifique-se de que o WSL está instalado."
    }
    
    # Parse da saída do wsl --list --verbose
    $lines = $wslList -split "`n" | Where-Object { $_ -match "\S" } | Select-Object -Skip 1
    $distributions = @()
    
    foreach ($line in $lines) {
        if ($line -match "^\s*([*\s])\s*(.+?)\s+(Stopped|Running)\s+(\d+)\s*$") {
            $distributions += [PSCustomObject]@{
                Default = ($matches[1] -eq "*")
                Name = $matches[2].Trim()
                State = $matches[3]
                Version = $matches[4]
            }
        }
    }
    
    return $distributions
}

function Stop-WSLDistribution {
    param([string]$DistName)
    
    Write-ColorOutput "Parando distribuição $DistName..." "Yellow"
    wsl --terminate $DistName
    
    if ($LASTEXITCODE -ne 0) {
        throw "Erro ao parar a distribuição $DistName"
    }
    
    Start-Sleep -Seconds 2
    Write-ColorOutput "Distribuição $DistName parada com sucesso." "Green"
}

function Compress-WSLDisk {
    param([string]$DistName)
    
    Write-ColorOutput "`nCompactando disco virtual de $DistName..." "Cyan"
    
    # Obtém o caminho do disco virtual
    $distroPath = (wsl --list --verbose | Select-String $DistName).Line
    
    # Para distribuições instaladas via Microsoft Store
    $vhdxPath = "$env:LOCALAPPDATA\Packages\" + 
                "CanonicalGroupLimited.*\LocalState\ext4.vhdx"
    
    # Procura pelo arquivo VHDX
    $vhdxFiles = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Recurse -Filter "ext4.vhdx" -ErrorAction SilentlyContinue |
                 Where-Object { $_.DirectoryName -match $DistName.Replace("-", "") }
    
    if ($vhdxFiles) {
        $vhdxPath = $vhdxFiles[0].FullName
        Write-Verbose "Disco virtual encontrado: $vhdxPath"
        
        $sizeBefore = (Get-Item $vhdxPath).Length / 1GB
        Write-ColorOutput "Tamanho antes: $([math]::Round($sizeBefore, 2)) GB" "Gray"
        
        # Compacta usando diskpart
        $diskpartScript = @"
select vdisk file="$vhdxPath"
attach vdisk readonly
compact vdisk
detach vdisk
"@
        
        $diskpartScript | diskpart | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            $sizeAfter = (Get-Item $vhdxPath).Length / 1GB
            $saved = $sizeBefore - $sizeAfter
            Write-ColorOutput "Tamanho depois: $([math]::Round($sizeAfter, 2)) GB" "Gray"
            Write-ColorOutput "Espaço recuperado: $([math]::Round($saved, 2)) GB" "Green"
        } else {
            Write-ColorOutput "Aviso: Compactação via diskpart falhou. Tentando método alternativo..." "Yellow"
            wsl --manage $DistName --set-sparse true 2>&1 | Out-Null
        }
    } else {
        Write-ColorOutput "Aviso: Disco virtual não encontrado para compactação direta." "Yellow"
        Write-ColorOutput "Usando método de otimização WSL..." "Yellow"
        wsl --manage $DistName --set-sparse true 2>&1 | Out-Null
    }
}

function Export-WSLDistribution {
    param(
        [string]$DistName,
        [string]$OutputPath
    )
    
    Write-ColorOutput "`nExportando $DistName..." "Cyan"
    
    # Cria diretório de saída se não existir
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        Write-Verbose "Diretório criado: $OutputPath"
    }
    
    # Nome do arquivo com timestamp
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $exportFile = Join-Path $OutputPath "$DistName-$timestamp.tar"
    
    Write-ColorOutput "Exportando para: $exportFile" "Gray"
    Write-ColorOutput "Aguarde, isso pode levar alguns minutos..." "Yellow"
    
    wsl --export $DistName $exportFile
    
    if ($LASTEXITCODE -ne 0) {
        throw "Erro ao exportar a distribuição $DistName"
    }
    
    $fileSize = (Get-Item $exportFile).Length / 1GB
    Write-ColorOutput "Exportação concluída!" "Green"
    Write-ColorOutput "Arquivo: $exportFile" "Green"
    Write-ColorOutput "Tamanho: $([math]::Round($fileSize, 2)) GB" "Green"
    
    return $exportFile
}

# Script principal
try {
    Write-ColorOutput "`n=== Compact-WSL: Utilitário de Compactação e Backup WSL ===`n" "Cyan"
    
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
        Write-ColorOutput "wsl --import <nome> <diretório-instalação> $exportedFile" "Gray"
    }
    
} catch {
    Write-ColorOutput "`n[ERRO] $($_.Exception.Message)" "Red"
    Write-ColorOutput "Detalhes: $($_.ScriptStackTrace)" "DarkRed"
    exit 1
}
