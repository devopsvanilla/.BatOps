#!/bin/bash

# --- Configurações de Ambiente ---
INPUT_DIR="./ovf-images"
OUTPUT_DIR="./output"
WORK_DIR="./work"
LOG_FILE="./conversion.log"

# Cores para o terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

set -euo pipefail

# --- Verificações Iniciais ---
mkdir -p "$OUTPUT_DIR" "$WORK_DIR"

log() { echo -e "$(date '+%F %T') | $1" | tee -a "$LOG_FILE" >&2; }
fail() { log "${RED}❌ ERRO: $1${NC}"; exit 1; }

# Checar dependências instaladas pelo setup-tools
for cmd in xmllint qemu-img virt-v2v virt-inspector; do
    command -v $cmd >/dev/null 2>&1 || fail "Comando '$cmd' não encontrado. Rode o ./setup-tools.sh primeiro."
done

# --- Funções de Extração ---
get_val() {
    local xpath="$1"
    local file="$2"
    xmllint --xpath "string($xpath)" "$file" 2>/dev/null || echo ""
}

# --- Processamento da VM ---
process_vm() {
    local ovf_path="$1"
    local vm_name=$(basename "$ovf_path" .ovf)
    local vm_output="$OUTPUT_DIR/$vm_name"
    local vm_work="$WORK_DIR/$vm_name"

    log "${GREEN}🚀 Iniciando Processamento Completo: $vm_name${NC}"
    
    # 1. Preparar área de trabalho isolada
    mkdir -p "$vm_output"
    rm -rf "$vm_work" && mkdir -p "$vm_work"
    
    cp "$ovf_path" "$vm_work/"
    # Copiar todos os VMDKs da pasta de origem
    cp "$(dirname "$ovf_path")"/*.vmdk "$vm_work/" 2>/dev/null || true

    pushd "$vm_work" > /dev/null
    local ovf_local=$(basename "$ovf_path")

    # 2. Extrair Hardware do OVF
    log "🔍 Extraindo metadados do XML..."
    local ram=$(get_val "//*[local-name()='Item'][*[local-name()='ResourceType']=4]/*[local-name()='VirtualQuantity']" "$ovf_local")
    local cpu=$(get_val "//*[local-name()='Item'][*[local-name()='ResourceType']=3]/*[local-name()='VirtualQuantity']" "$ovf_local")
    local firmware="bios"
    [[ $(grep -iE "efi|uefi" "$ovf_local") ]] && firmware="efi"

    [ -z "$ram" ] && ram="4096"
    [ -z "$cpu" ] && cpu="2"

    # 3. Mapear e Normalizar Discos (Suporta múltiplos discos)
    log "📦 Normalizando discos (VMDK -> Flat)..."
    mapfile -t vmdk_list < <(xmllint --xpath "//*[local-name()='File']/@*[local-name()='href']" "$ovf_local" | grep -oP 'href="\K[^"]+')
    
    declare -a flat_disks=()
    for i in "${!vmdk_list[@]}"; do
        local src="${vmdk_list[$i]}"
        local dst="disk${i}-flat.vmdk"
        log "   -> Convertendo $src para $dst..."
        qemu-img convert -p -f vmdk -O vmdk -o subformat=monolithicFlat "$src" "$dst"
        flat_disks+=("$dst")
    done

    # 4. Criar Descritor VMX (Ponte de Metadados)
    log "📝 Gerando ponte VMX (Firmware: $firmware, RAM: ${ram}MB)..."
    {
        echo "config.version = \"8\""
        echo "virtualHW.version = \"11\""
        echo "memsize = \"$ram\""
        echo "numvcpus = \"$cpu\""
        echo "firmware = \"$firmware\""
        echo "guestOS = \"windows9-64\""
        
        for i in "${!flat_disks[@]}"; do
            echo "scsi0:$i.present = \"TRUE\""
            echo "scsi0:$i.fileName = \"${flat_disks[$i]}\""
            echo "scsi0:$i.deviceType = \"scsi-hardDisk\""
        done
        echo "scsi0.present = \"TRUE\""
        echo "scsi0.virtualDev = \"lsilogicsas\""
    } > "temp.vmx"

    # 5. Executar virt-v2v (A Conversão Real)
    log "🔄 Executando virt-v2v (Injeção de drivers e conversão QCOW2)..."
    
    # Configurar ambiente para WSL2/Direct Backend
    export LIBGUESTFS_BACKEND=direct
    if [ -d "/usr/lib/x86_64-linux-gnu/guestfs" ]; then
        export LIBGUESTFS_PATH="/usr/lib/x86_64-linux-gnu/guestfs"
    fi

    # O comando virt-v2v propriamente dito
    local out_abs
    out_abs=$(realpath "../../$vm_output")

    if ! virt-v2v -i vmx "temp.vmx" -o local -os "$out_abs" --network none 2>v2v_error.log; then
        log "${RED}❌ Falha na inspeção do SO.${NC}"
        log "Tentando diagnóstico com virt-inspector..."
        virt-inspector -a "${flat_disks[0]}" > "inspector_report.txt" 2>&1 || true
        echo "------------------------------------------------" >&2
        cat v2v_error.log >&2
        echo "------------------------------------------------" >&2
        popd > /dev/null
        return 1
    fi

    # 6. Limpeza de ficheiros de trabalho (opcional, remova se quiser depurar)
    log "🧹 Limpando ficheiros temporários..."
    popd > /dev/null
    rm -rf "$vm_work"

    log "${GREEN}✅ VM '$vm_name' concluída com sucesso!${NC}"
}

# --- Início do Script ---
log "${YELLOW}🔎 Iniciando busca de ficheiros OVF em $INPUT_DIR...${NC}"

# Verificar se a pasta de entrada existe
[ ! -d "$INPUT_DIR" ] && fail "Pasta de entrada $INPUT_DIR não existe."

find "$INPUT_DIR" -name "*.ovf" | while read -r f; do
    process_vm "$f" || log "${RED}⚠️ Erro ao processar $f. Veja o log.${NC}"
done

log "${GREEN}🎉 Todo o processo de conversão BatOps foi finalizado!${NC}"
