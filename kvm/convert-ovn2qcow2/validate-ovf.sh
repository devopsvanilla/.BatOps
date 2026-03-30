#!/usr/bin/env bash
# TODO: Revisar e adicionar set -euo pipefail — Issue #1

INPUT_DIR="./ovf-images"
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}📊 Relatório Técnico de Integridade BatOps (OVF vs VMDK)${NC}"
echo "----------------------------------------------------------------------------------------------------------"
printf "%-20s | %-12s | %-10s | %-10s | %-15s | %-s\n" "VM NAME" "FORMAT" "OVF_EXP" "REAL_SIZE" "VIRT_CAP" "STATUS"
echo "----------------------------------------------------------------------------------------------------------"

find "$INPUT_DIR" -name "*.ovf" | while read -r ovf_file; do
    vm_name=$(basename "$ovf_file" .ovf)
    ovf_dir=$(dirname "$ovf_file")

    # 1. Extração de Metadados do OVF
    vmdk_name=$(xmllint --xpath "string(//*[local-name()='File']/@*[local-name()='href'])" "$ovf_file" 2>/dev/null)
    ovf_expected_bytes=$(xmllint --xpath "string(//*[local-name()='File']/@*[local-name()='size'])" "$ovf_file" 2>/dev/null || echo "0")
    virt_capacity_gb=$(xmllint --xpath "string(//*[local-name()='Disk']/@*[local-name()='capacity'])" "$ovf_file" 2>/dev/null || echo "0")
    
    vmdk_path="$ovf_dir/$vmdk_name"

    if [ ! -f "$vmdk_path" ]; then
        printf "%-20s | %-12s | %-10s | %-10s | %-15s | %-b\n" "$vm_name" "---" "---" "---" "${virt_capacity_gb}GB" "${RED}MISSING FILE${NC}"
        continue
    fi

    # 2. Análise Real do arquivo via qemu-img
    # Extraímos o formato e o tamanho virtual detectado no binário
    img_info=$(qemu-img info "$vmdk_path" 2>/dev/null || echo "")
    vmdk_format=$(echo "$img_info" | grep "create type" | awk -F: '{print $2}' | xargs || echo "unknown")
    [ "$vmdk_format" == "unknown" ] && vmdk_format=$(echo "$img_info" | grep "file format" | awk -F: '{print $2}' | xargs)

    # 3. Cálculo de Tamanhos
    actual_size_bytes=$(stat -c%s "$vmdk_path")
    
    # Formatação para exibição
    ovf_exp_fmt=$(awk "BEGIN {printf \"%.2fMB\", $ovf_expected_bytes/1024/1024}")
    real_size_fmt=$(awk "BEGIN {printf \"%.2fMB\", $actual_size_bytes/1024/1024}")
    
    # 4. Lógica de Validação
    status="${GREEN}OK${NC}"
    
    # Validação A: Tamanho irrisório (O seu caso do Header de 70KB)
    if [ "$actual_size_bytes" -lt 1000000 ] && [ "$virt_capacity_gb" -gt 0 ]; then
        status="${RED}DUMMY_HEADER${NC}"
    
    # Validação B: Formato Incompatível ou Corrompido
    elif [[ "$img_info" == "" ]]; then
        status="${RED}CORRUPT_IMG${NC}"
    
    # Validação C: StreamOptimized (Aviso de que precisa converter para Flat antes)
    elif [[ "$vmdk_format" == *"streamOptimized"* ]]; then
        status="${YELLOW}OK (COMPRESSED)${NC}"
    fi

    printf "%-20s | %-12s | %-10s | %-10s | %-15s | %-b\n" \
        "$vm_name" "$vmdk_format" "$ovf_exp_fmt" "$real_size_fmt" "${virt_capacity_gb}GB" "$status"

done
echo "----------------------------------------------------------------------------------------------------------"
echo -e "${CYAN}💡 DICA:${NC} Se o status for ${RED}DUMMY_HEADER${NC}, a exportação do vSphere não incluiu os dados (ficheiro -flat)."
