# Compactar WSL com backup seguro
# Requisitos: Executar como administrador

function Get-WSLDistributions {
    wsl --list --verbose | Select-String -Pattern '^\s*(\S+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
}

function Get-WSLLocation($distro) {
    $base = "$env:LOCALAPPDATA\Packages"
    Get-ChildItem $base | Where-Object {
        Test-Path "$($_.FullName)\LocalState" -and
        (Get-Content "$($_.FullName)\LocalState\DistroName" -ErrorAction SilentlyContinue) -eq $distro
    } | Select-Object -First 1 | ForEach-Object { "$($_.FullName)\LocalState" }
}

function Get-WSLDiskSize($vhdxPath) {
    (Get-Item $vhdxPath).Length / 1GB
}

function Get-FreeSpace($driveLetter) {
    (Get-PSDrive $driveLetter).Free / 1GB
}

function Backup-WSL($distro, $backupPath) {
    wsl --export $distro $backupPath
}

function Compact-VHDX($vhdxPath) {
    diskpart /s - <<EOF
select vdisk file="$vhdxPath"
attach vdisk readonly
compact vdisk
detach vdisk
EOF
}

# 1. Listar distribuições
$distros = Get-WSLDistributions
Write-Host "Distribuições disponíveis:"
$distros | ForEach-Object { Write-Host "- $_" }

# 2. Escolher distribuição
$distro = Read-Host "Digite o nome da distribuição que deseja compactar"
if (-not ($distros -contains $distro)) {
    Write-Host "Distribuição inválida." -ForegroundColor Red
    exit
}

# 3. Obter local e tamanho
$localState = Get-WSLLocation $distro
$vhdxPath = "$localState\ext4.vhdx"
if (-not (Test-Path $vhdxPath)) {
    Write-Host "Disco virtual não encontrado." -ForegroundColor Red
    exit
}
$tamanho = Get-WSLDiskSize $vhdxPath
$drive = $localState.Substring(0,1)
$livre = Get-FreeSpace $drive

Write-Host "Tamanho do disco: {0:N2} GB" -f $tamanho
Write-Host "Espaço livre em $drive: {0:N2} GB" -f $livre

# 4. Verificar espaço
if ($livre -lt $tamanho) {
    Write-Host "Espaço insuficiente para backup." -ForegroundColor Red
    exit
}

# 5. Backup
$backupDir = "$env:USERPROFILE\WSL_Backups"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$backupFile = "$backupDir\$distro.bkp"

if (Test-Path $backupFile) {
    $choice = Read-Host "Backup já existe. Deseja substituir (S) ou criar novo (N)?"
    if ($choice -eq "N") {
        $timestamp = Get-Date -Format "yyyyMMddHHmm"
        $backupFile = "$backupDir\$distro.$timestamp.tar"
    }
}

Write-Host "Criando backup em: $backupFile"
Backup-WSL $distro $backupFile

# 6. Parar WSL
wsl --shutdown
Start-Sleep -Seconds 3

# 7. Compactar
Write-Host "Compactando disco..."
Compact-VHDX $vhdxPath

# 8. Reiniciar WSL
wsl -d $distro

Write-Host "Operação concluída com sucesso!" -ForegroundColor Green
