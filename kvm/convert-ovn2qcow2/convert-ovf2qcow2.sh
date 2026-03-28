#!/bin/bash

# --- Cores e Emojis ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CHECK="✅"
CROSS="❌"
WARN="⚠️"
INFO="ℹ️"
ROCKET="🚀"
PACKAGE="📦"

# --- Variáveis Padrão ---
SOURCE_DIR="./ovf-images"
TARGET_DIR="./qcow2-images"
FORMAT="qcow2"
DRY_RUN=0

# --- Ajuda ---
show_help() {
    echo -e "${BLUE}${INFO} convert-ovf2qcow2 - Conversor de imagens VMware (OVF/OVA) para KVM${NC}"
    echo "Uso: $0 [OPÇÕES]"
    echo ""
    echo "Opções:"
    echo "  --source-dir DIR    Diretório de origem das imagens OVF/OVA (padrão: ./ovf-images)"
    echo "  --target-dir DIR    Diretório de destino das imagens convertidas (padrão: ./qcow2-images)"
    echo "  --format FMT        Formato de destino (padrão: qcow2)"
    echo "  --dry-run           Apenas simula a execução, sem converter imagens reais"
    echo "  --help              Mostra esta mensagem de ajuda"
    echo ""
}

# --- Parsing de Parâmetros ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --source-dir) SOURCE_DIR="$2"; shift ;;
        --target-dir) TARGET_DIR="$2"; shift ;;
        --format) FORMAT="$2"; shift ;;
        --dry-run) DRY_RUN=1 ;;
        --help) show_help; exit 0 ;;
        *) echo -e "${RED}${CROSS} Parâmetro desconhecido: $1${NC}"; show_help; exit 1 ;;
    esac
    shift
done

# --- Funções ---

# Verifica e instala dependências no Ubuntu
check_dependencies() {
    echo -e "\n${BLUE}${INFO} Verificando dependências para o sistema local (Ubuntu)...${NC}"
    
    local DEPS=("virt-v2v" "libguestfs-tools" "qemu-utils")
    local MISSING_DEPS=()

    for dep in "${DEPS[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            MISSING_DEPS+=("$dep")
        fi
    done

    if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
        echo -e "${GREEN}${CHECK} Todas as dependências necessárias estão instaladas!${NC}"
        return
    fi

    echo -e "${YELLOW}${WARN} As seguintes dependências não foram encontradas: ${MISSING_DEPS[*]}${NC}"
    
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "${INFO} [Dry Run] Simularia a instalação dos pacotes via apt: ${MISSING_DEPS[*]}"
        return
    fi

    read -p "Deseja instalar as dependências agora via apt? [Y/n] " response
    response=${response,,} # tolower
    if [[ "$response" =~ ^(sim|s|yes|y|)$ ]]; then
        echo -e "${INFO} Atualizando lista de pacotes e instalando dependências... Isso exigirá privilégios de sudo.${NC}"
        sudo apt-get update
        sudo apt-get install -y "${MISSING_DEPS[@]}"
        
        # Testando novamente se instalou corretamente
        for dep in "${MISSING_DEPS[@]}"; do
            if ! command -v "$dep" &> /dev/null; then
                 echo -e "${RED}${CROSS} Falha ao instalar o pacote $dep. Verifique a sua conexão ou sistema de pacotes.${NC}"
                 exit 1
            fi
        done
        
        echo -e "${GREEN}${CHECK} Dependências resolvidas com sucesso!${NC}"
    else
        echo -e "${RED}${CROSS} Impossível prosseguir sem as dependências. Abortando.${NC}"
        exit 1
    fi
}

verify_manifest() {
    local ovf_file="$1"
    local base_name="${ovf_file%.ovf}"
    local mf_file="${base_name}.mf"
    
    if [ ! -f "$mf_file" ]; then
        echo -e "${YELLOW}${WARN} Arquivo de manifesto não encontrado: $(basename "$mf_file") . Verificação de integridade ignorada.${NC}"
        return 0
    fi
    
    echo -e "${INFO} Arquivo de manifesto encontrado ($(basename "$mf_file")). Verificando integridade..."
    
    local dir_path=$(dirname "$ovf_file")
    pushd "$dir_path" > /dev/null
    
    local HAS_ERROR=0
    
    # Extrair arquivos mencionados e verificar
    if grep -q "SHA1(" "$(basename "$mf_file")"; then
        awk -F '[()= ]' '/SHA1/ {print $5"  "$3}' "$(basename "$mf_file")" | sha1sum -c --status
        if [ $? -ne 0 ]; then
            HAS_ERROR=1
        fi
    elif grep -q "SHA256(" "$(basename "$mf_file")"; then
        awk -F '[()= ]' '/SHA256/ {print $5"  "$3}' "$(basename "$mf_file")" | sha256sum -c --status
        if [ $? -ne 0 ]; then
            HAS_ERROR=1
        fi
    else
        echo -e "${YELLOW}${WARN} Formato de hash desconhecido no arquivo .mf.${NC}"
        popd > /dev/null
        return 0
    fi
    
    popd > /dev/null
    
    if [ "$HAS_ERROR" -eq 1 ]; then
         echo -e "${RED}${CROSS} Falha na verificação de integridade! Arquivos corrompidos ou alterados em relação ao $mf_file.${NC}"
         return 1
    fi
    
    echo -e "${GREEN}${CHECK} Integridade validada com sucesso via $mf_file!${NC}"
    return 0
}

# --- Execução Principal ---
echo -e "${BLUE}${ROCKET} Iniciando conversão de VMware OVF/OVA para KVM ($FORMAT)...${NC}"

# Cria estrutura de diretórios
if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$SOURCE_DIR"
    mkdir -p "$TARGET_DIR"
else
    echo -e "${INFO} [Dry Run] Simularia a criação dos diretórios caso não existam: $SOURCE_DIR, $TARGET_DIR"
fi

check_dependencies

echo -e "\n${INFO} Escaneando o diretório de origem (${SOURCE_DIR}) por arquivos .ovf ou .ova...${NC}"

shopt -s nullglob
FILES=("$SOURCE_DIR"/*.ovf "$SOURCE_DIR"/*.ova)
shopt -u nullglob

if [ ${#FILES[@]} -eq 0 ]; then
    echo -e "${YELLOW}${WARN} Nenhuma imagem encontrada no diretório: $SOURCE_DIR${NC}"
    exit 0
fi

TOTAL_FILES=${#FILES[@]}
CONVERTED=0
ERRORS=0

echo -e "${INFO} Foram encontradas $TOTAL_FILES imagem(ns) pronta(s) para processamento.\n"

export LIBGUESTFS_BACKEND=direct

for file in "${FILES[@]}"; do
    FILENAME=$(basename -- "$file")
    EXTENSION="${FILENAME##*.}"
    BASENAME="${FILENAME%.*}"
    
    echo -e "------------------------------------------------------"
    echo -e "${PACKAGE} Processando imagem: ${BLUE}$FILENAME${NC}"
    
    # Se for .ovf, testar manifesto
    if [ "${EXTENSION,,}" == "ovf" ]; then
        if ! verify_manifest "$file"; then
             ERRORS=$((ERRORS + 1))
             continue
        fi
    fi
    
    echo -e "${INFO} Convertendo VM '${BASENAME}'... (isso pode demorar dependendo do tamanho dos discos)"
    
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "${INFO} [Dry Run] Comando: virt-v2v -i ova \"$file\" -on \"$BASENAME\" -o local -os \"$TARGET_DIR\" -of \"$FORMAT\""
        CONVERTED=$((CONVERTED + 1))
        echo -e "${GREEN}${CHECK} [Simulação] $BASENAME convertido(a) simuladamente.${NC}"
    else
        # Vamos rodar o virt-v2v passsando config local, o caminho output e o formato qcow2.
        # -on define o nome exato da VM e arquivos de disco resultantes
        virt-v2v -i ova "$file" -on "$BASENAME" -o local -os "$TARGET_DIR" -of "$FORMAT" 
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${CHECK} Imagem '$BASENAME' convertida com sucesso!${NC}"
            CONVERTED=$((CONVERTED + 1))
            
            # Verificar integridade da imagem convertida
            if ls "$TARGET_DIR/$BASENAME"*."$FORMAT" 1> /dev/null 2>&1 || ls "$TARGET_DIR/$BASENAME"*-sda 1> /dev/null 2>&1; then
                echo -e "${INFO} Verificando imagens de disco virtuais exportadas pelo qemu-img..."
                
                # Procura explicitamente por arquivos gerados vinculados ao BASENAME e ao FORMAT
                for disk in "$TARGET_DIR/$BASENAME"*."$FORMAT" "$TARGET_DIR/$BASENAME"*-sda "$TARGET_DIR/$BASENAME"*-?da; do
                    if [ -f "$disk" ]; then
                        qemu-img check "$disk" > /dev/null 2>&1
                        if [ $? -eq 0 ]; then
                           echo -e "${GREEN}${CHECK} Verificação do disco $(basename "$disk") completada sem falhas estruturais.${NC}"
                        else
                           echo -e "${YELLOW}${WARN} Verificação do qemu-img apontou fragmentação vazia ou avisos no disco $(basename "$disk").${NC}"
                        fi
                    fi
                done
            fi
        else
            echo -e "${RED}${CROSS} Erro retornado ao formatar imagem baseada no arquivo $FILENAME.${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

echo -e "\n======================================================"
echo -e "${BLUE}${ROCKET} RESUMO DA EXECUÇÃO ${NC}"
echo -e "======================================================"
echo -e "Imagens localizadas: $TOTAL_FILES"
echo -e "${GREEN}${CHECK} Convertidas com Sucesso: $CONVERTED${NC}"
if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}${CROSS} Erros/Alertas durante processo: $ERRORS${NC}"
else
    echo -e "${GREEN}${CHECK} Nenhum Erro. Todos convertidos.${NC}"
fi
echo -e ""
echo -e "${YELLOW}${WARN} AVISOS GERAIS PARA AS IMAGENS:${NC}"
echo -e " 1. Endereços MAC de rede mapeados (vSwitches distribuídos) são redefinidos na ponte do XML."
echo -e " 2. Snapshots preservados no VMware do formato hierárquico são suprimidos e mesclados à base consolidada."
echo -e " 3. Dispositivos pass-through tipo PCI/USB antigos removidos do template resultante de hardware."
echo -e "======================================================\n"

exit $ERRORS
