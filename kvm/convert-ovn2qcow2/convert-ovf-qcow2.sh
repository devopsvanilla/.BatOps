#!/usr/bin/env bash

# --- Configurações de Ambiente ---
INPUT_DIR="./ovf-images"
OUTPUT_DIR="./output"
WORK_DIR="./work"
LOG_FILE="./conversion.log"

# Cores para o terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

FORCE_EOL=false

# --- Parsing de Argumentos ---
for arg in "$@"; do
    case $arg in
        --force-wineol)
            FORCE_EOL=true
            ;;
        --help)
            echo "Uso: $0 [--force-wineol]"
            echo "Opções:"
            echo "  --force-wineol    Permite a conversão de imagens detectadas como Windows EOL (XP, 7, 8.1, Server 2012, etc)"
            exit 0
            ;;
    esac
done

set -euo pipefail

# --- Funções Utilitárias ---
log() { echo -e "$(date '+%F %T') | $1" | tee -a "$LOG_FILE" >&2; }
fail() { log "${RED}❌ ERRO: $1${NC}"; exit 1; }

get_val() {
    local xpath="$1"
    local file="$2"
    xmllint --xpath "string($xpath)" "$file" 2>/dev/null || echo ""
}

# --- Funções de Display e UX ---
human_size() {
    local bytes=$1
    if   (( bytes >= 1073741824 )); then printf "%.1f GB" "$(echo "scale=1; $bytes/1073741824" | bc)"
    elif (( bytes >= 1048576 ))   ; then printf "%.1f MB" "$(echo "scale=1; $bytes/1048576"    | bc)"
    else                                 printf "%d KB"   "$(( bytes / 1024 ))"
    fi
}

divider() { echo -e "${DIM}──────────────────────────────────────────────────${NC}"; }
header()  {
    echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  $*${NC}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${NC}\n"
}

# --- Spinner ---
spinner_pid=""
start_spinner() {
    local msg=$1
    local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    ( local i=0
      while true; do
          printf "\r  ${CYAN}%s${NC} %s " "${spin[$i]}" "$msg"
          i=$(( (i+1) % ${#spin[@]} ))
          sleep 0.1
      done ) &
    spinner_pid=$!
}
stop_spinner() {
    if [[ -n "$spinner_pid" ]]; then
        kill "$spinner_pid" 2>/dev/null || true
        wait "$spinner_pid" 2>/dev/null || true
        spinner_pid=""
        printf "\r\033[K"
    fi
}

# --- Cleanup e Trap ---
CURRENT_VM_WORK=""
cleanup() {
    stop_spinner
    if [[ -n "$CURRENT_VM_WORK" && -d "$CURRENT_VM_WORK" ]]; then
        log "${YELLOW}⚠️  Interrompido! Removendo diretório parcial: $CURRENT_VM_WORK${NC}"
        rm -rf "$CURRENT_VM_WORK"
    fi
}
trap cleanup EXIT INT TERM

# --- Scan inicial para detecção de Windows EOL ---
WINEOL_FOUND=false
EOL_REGEX="([Xx][Pp]|[Ww]indows 7|[Ww]indows 8\.1|[Ss]erver 2012|1809|1903|1909|2004|20[Hh]2|21[Hh]1|21[Hh]2|22[Hh]2|[Ll][Tt][Ss][Bb])"

log "${YELLOW}🔎 Escaneando imagens para detecção de sistemas legados...${NC}"
# Usamos find e checagem simples de XML para o prompt global
while read -r ovf; do
    if [ ! -f "$ovf" ]; then continue; fi
    desc=$(xmllint --xpath "string(//*[local-name()='OperatingSystemSection']/*[local-name()='Description'])" "$ovf" 2>/dev/null || echo "")
    type=$(xmllint --xpath "string(//*[local-name()='OperatingSystemSection']/@*[local-name()='osType'])" "$ovf" 2>/dev/null || echo "")
    if [[ "$desc" =~ $EOL_REGEX ]] || [[ "$type" =~ $EOL_REGEX ]]; then
        WINEOL_FOUND=true
        break
    fi
done < <(find "$INPUT_DIR" -name "*.ovf" 2>/dev/null)

VIRTIO_MODE="latest"
if [ "$WINEOL_FOUND" = true ]; then
    echo -e "\n${YELLOW}🎨 [VIRTIO] Sistemas Windows legados (EOL) detetados no lote!${NC}"
    echo -e "👉 Escolha a versão dos Drivers VirtIO para injeção nestas máquinas:"
    echo -e "   1) 📀 ${GREEN}Legacy${NC} (0.1.185) - [RECOMENDADO para WinEOL]"
    echo -e "   2) 🚀 ${YELLOW}Modern${NC} (Stable) - [Pode causar instabilidade em sistemas antigos]"
    echo -ne "Opção [1]: "
    # Desativar set -e temporariamente para o read não quebrar se o usuário der Ctrl+D
    set +e
    read -r opt
    set -e
    case $opt in
        2) VIRTIO_MODE="latest" ;;
        *) VIRTIO_MODE="legacy" ;;
    esac
    echo -e "✅ Configuração global WinEOL: ${GREEN}$VIRTIO_MODE${NC}\n"
fi

# --- Verificações Iniciais ---
mkdir -p "$OUTPUT_DIR" "$WORK_DIR"

# Checar dependências instaladas pelo setup-tools
for cmd in xmllint qemu-img virt-v2v virt-inspector bc; do
    command -v "$cmd" >/dev/null 2>&1 || fail "Comando '$cmd' não encontrado. Rode o ./setup-tools.sh primeiro."
done

# --- Processamento da VM ---
process_vm() {
    local ovf_path="$1"
    local vm_name
    vm_name=$(basename "$ovf_path" .ovf)
    local vm_output="$OUTPUT_DIR/$vm_name"
    local vm_work="$WORK_DIR/$vm_name"

    log "${GREEN}🚀 Iniciando Processamento Completo: $vm_name${NC}"

    # 1. Preparar área de trabalho isolada
    mkdir -p "$vm_output"
    rm -rf "$vm_work" && mkdir -p "$vm_work"
    CURRENT_VM_WORK="$vm_work"

    # Verificar espaço disponível antes de iniciar
    local vmdk_total_size=0
    while IFS= read -r vmdk_src; do
        local sz
        sz=$(stat -c%s "$vmdk_src" 2>/dev/null || echo 0)
        vmdk_total_size=$(( vmdk_total_size + sz ))
    done < <(find "$(dirname "$ovf_path")" -maxdepth 1 -name "*.vmdk" 2>/dev/null)
    if (( vmdk_total_size > 0 )); then
        local work_avail output_avail
        work_avail=$(df -B1 --output=avail "$WORK_DIR" 2>/dev/null | tail -1 | tr -d ' ')
        output_avail=$(df -B1 --output=avail "$OUTPUT_DIR" 2>/dev/null | tail -1 | tr -d ' ')
        log "💾 Tamanho VMDKs: $(human_size "$vmdk_total_size") | Livre work: $(human_size "$work_avail") | Livre output: $(human_size "$output_avail")"
        if (( work_avail < vmdk_total_size )); then
            log "${YELLOW}⚠️  AVISO: Espaço em $WORK_DIR pode ser insuficiente para os arquivos de trabalho.${NC}"
        fi
        if (( output_avail < vmdk_total_size )); then
            log "${YELLOW}⚠️  AVISO: Espaço em $OUTPUT_DIR pode ser insuficiente para a imagem qcow2 final.${NC}"
        fi
    fi

    cp "$ovf_path" "$vm_work/"
    # Copiar todos os VMDKs da pasta de origem
    cp "$(dirname "$ovf_path")"/*.vmdk "$vm_work/" 2>/dev/null || true

    pushd "$vm_work" > /dev/null
    local ovf_local
    ovf_local=$(basename "$ovf_path")

    # 2. Extrair Hardware e SO do OVF
    log "🔍 Extraindo metadados do XML..."
    local ram
    ram=$(get_val "//*[local-name()='Item'][*[local-name()='ResourceType']=4]/*[local-name()='VirtualQuantity']" "$ovf_local")
    local cpu
    cpu=$(get_val "//*[local-name()='Item'][*[local-name()='ResourceType']=3]/*[local-name()='VirtualQuantity']" "$ovf_local")

    local os_desc
    os_desc=$(get_val "//*[local-name()='OperatingSystemSection']/*[local-name()='Description']" "$ovf_local")
    local os_type
    os_type=$(xmllint --xpath "string(//*[local-name()='OperatingSystemSection']/@*[local-name()='osType'])" "$ovf_local" 2>/dev/null || echo "")

    log "🖥️  SO Detectado: ${YELLOW}${os_desc:-Desconhecido} ($os_type)${NC}"

    # Verificação de Windows EOL (End of Life)
    # Regex para capturar: XP, 7, 8.1, Server 2012 e builds específicas de Win10 EOL
    local eol_regex="([Xx][Pp]|[Ww]indows 7|[Ww]indows 8\.1|[Ss]erver 2012|1809|1903|1909|2004|20[Hh]2|21[Hh]1|21[Hh]2|22[Hh]2|[Ll][Tt][Ss][Bb])"

    if [[ "$os_desc" =~ $eol_regex ]] || [[ "$os_type" =~ $eol_regex ]]; then
        if [ "$FORCE_EOL" = false ]; then
            log "${YELLOW}⚠️  Aviso: Sistema EOL detectado (${os_desc:-$os_type}). Use --force-wineol para processar.${NC}"
            log "   Pulando conversão de $vm_name..."
            popd > /dev/null
            return 0
        fi
        log "${YELLOW}⚡ Processando Sistema EOL: ${os_desc} (Modo Forçado Ativo)${NC}"
    fi

    # Mapeamento do guestOS para o VMX
    local vmx_os="windows9-64" # Default para Win10 moderno
    [[ "$os_type" =~ [Xx][Pp] ]] && vmx_os="winxpGuest"
    [[ "$os_type" =~ "win7" ]] && vmx_os="windows7-64"
    [[ "$os_type" =~ "win8" ]] && vmx_os="windows8-64"
    [[ "$os_type" =~ "2012" ]] && vmx_os="windows8Server64Guest"

    local firmware="bios"
    grep -qiE "efi|uefi" "$ovf_local" && firmware="efi"

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

    # 3.1 Verificações de Integridade e Saúde
    if [ ! -d "/usr/share/virtio-win" ] || [ -z "$(ls -A /usr/share/virtio-win 2>/dev/null)" ]; then
        log "${YELLOW}⚠️  AVISO: Pasta /usr/share/virtio-win/ está vazia ou ausente.${NC}"
        log "   O virt-v2v pode falhar ao injetar drivers ou causar BSOD no Windows XP."
    fi

    # 4. Criar Descritor VMX (Ponte de Metadados)
    log "📝 Gerando ponte VMX (Firmware: $firmware, RAM: ${ram}MB)..."
    {
        echo "config.version = \"8\""
        echo "virtualHW.version = \"11\""
        echo "displayName = \"$vm_name\""
        echo "memsize = \"$ram\""
        echo "numvcpus = \"$cpu\""
        echo "guestOS = \"$vmx_os\""

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

    # Seleção do diretório de drivers baseado no SO e na escolha global
    local current_virtio="/usr/share/virtio-win/latest"
    local is_eol=false
    if [[ "$os_desc" =~ $eol_regex ]] || [[ "$os_type" =~ $eol_regex ]]; then
        current_virtio="/usr/share/virtio-win/$VIRTIO_MODE"
        is_eol=true
    fi

    # Configurar ambiente para WSL2/Direct Backend
    export LIBGUESTFS_BACKEND=direct
    if [ -d "/usr/lib/x86_64-linux-gnu/guestfs" ]; then
        export LIBGUESTFS_PATH="/usr/lib/x86_64-linux-gnu/guestfs"
    fi

    # O comando virt-v2v propriamente dito
    local out_abs
    out_abs=$(realpath "../../$vm_output")

    start_spinner "Executando virt-v2v — isso pode levar vários minutos..."
    if ! VIRTIO_WIN="$current_virtio" virt-v2v -i vmx "temp.vmx" -o local -os "$out_abs" -of qcow2 -oa sparse --network none 2>v2v_error.log; then
        stop_spinner
        log "${RED}❌ Erro Crítico na Conversão.${NC}"
        echo "----------------- [ LOG DE ERRO VIRT-V2V ] -----------------" >&2
        cat v2v_error.log >&2
        echo "------------------------------------------------------------" >&2
        log "Tentando diagnóstico com virt-inspector..."
        virt-inspector -a "${flat_disks[0]}" > "inspector_report.txt" 2>&1 || true
        popd > /dev/null
        return 1
    fi
    stop_spinner

    # 5.1 Ajuste de extensibilidade (Re-nomear discos para .qcow2 e atualizar XML)
    log "✨ Finalizando formatação e extensões..."
    # Localizar os nomes de arquivo originais no XML (que o virt-v2v gera sem extensão)
    # e renomear fisicamente além de atualizar o descritor XML
    while read -r disk_file; do
        if [ -f "$out_abs/$disk_file" ]; then
            mv "$out_abs/$disk_file" "$out_abs/$disk_file.qcow2"
            sed -i "s|'$out_abs/$disk_file'|'$out_abs/$disk_file.qcow2'|g" "$out_abs/$vm_name.xml"
        fi
    done < <(grep -oP "source file='\K[^']*(?=/|$out_abs/)" "$out_abs/$vm_name.xml" | xargs -n1 basename | sort -u)

    # 5.2 Verificação de integridade das imagens qcow2 geradas
    log "🔬 Verificando integridade das imagens qcow2..."
    while IFS= read -r qcow2_file; do
        local check_out file_size
        file_size=$(stat -c%s "$qcow2_file" 2>/dev/null || echo 0)
        log "   📁 $(basename "$qcow2_file") — $(human_size "$file_size") em disco"
        start_spinner "Verificando $(basename "$qcow2_file")..."
        if check_out=$(qemu-img check "$qcow2_file" 2>&1); then
            stop_spinner
            log "${GREEN}   ✅ Verificação OK: $(basename "$qcow2_file")${NC}"
        else
            stop_spinner
            log "${YELLOW}   ⚠️  qemu-img check reportou issues (pode ser não-crítico): $(basename "$qcow2_file")${NC}"
            echo "$check_out" >&2
        fi
    done < <(find "$out_abs" -maxdepth 1 -name "*.qcow2" 2>/dev/null)

    # 6. Gerar README.txt de diagnóstico
    log "📄 Gerando relatório de conversão..."
    {
        echo "================================================================"
        echo "📦 RELATÓRIO DE CONVERSÃO BATOPS - $vm_name"
        echo "================================================================"
        echo "Data: $(date '+%F %T')"
        echo "Sistema Operacional: ${os_desc:-$os_type}"
        echo "Drivers VirtIO: $current_virtio"
        echo "----------------------------------------------------------------"

        if [ "$is_eol" = true ]; then
            echo "⚠️  AVISO DE SISTEMA LEGADO (WinEOL)"
            echo "Este OS está fora do suporte oficial. Os drivers injetados"
            echo "foram selecionados via prompt global (Modo: $VIRTIO_MODE)."
            echo ""
            echo "📋 COMO TESTAR COMPATIBILIDADE:"
            echo "1. Boot KVM: Se ocorrer BSOD 0x0000007B, os drivers de disco"
            echo "   falharam. Tente reprocessar com a outra versão de drivers."
            echo "2. Gerenciador de Dispositivos: Procure por 'Red Hat VirtIO'"
            echo "   em Controladores SCSI e Adaptadores de Rede."
            echo "3. Rede: Se não houver rede, verifique se o driver 'NetKVM'"
            echo "   foi carregado corretamente."
        else
            echo "🚀 SISTEMA MODERNO"
            echo "Drivers estáveis aplicados com sucesso."
            echo ""
            echo "📋 RECOMENDAÇÕES:"
            echo "1. Valide a performance de I/O em discos virtio-scsi."
            echo "2. Instale o QEMU Guest Agent se não houver sido injetado."
        fi
        echo ""
        echo "🛠️  IMPORTAÇÃO NO KVM (Libvirt):"
        echo "Para subir esta VM no host KVM de destino, execute:"
        echo "  virsh define $out_abs/$vm_name.xml"
        echo "  virsh start $vm_name"
        echo "----------------------------------------------------------------"
        echo "BatOps - Infrastructure & Automation"
    } > "$out_abs/README.txt"

    # 7. Limpeza de ficheiros de trabalho (opcional, remova se quiser depurar)
    log "🧹 Limpando ficheiros temporários..."
    popd > /dev/null
    rm -rf "$vm_work"
    CURRENT_VM_WORK=""

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
