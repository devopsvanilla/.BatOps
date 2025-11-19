#!/bin/bash
set -euo pipefail

# Desabilita pipefail para permitir que o script continue após o ZAP retornar exit code não-zero
set +o pipefail

# Definição de cores
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para verificar e instalar dependências
check_and_install_dependencies() {
  local missing_deps=()
  
  # Verifica Docker
  if ! command -v docker >/dev/null 2>&1; then
    missing_deps+=("docker.io")
  fi
  
  # Verifica wkhtmltopdf
  if ! command -v wkhtmltopdf >/dev/null 2>&1; then
    missing_deps+=("wkhtmltopdf")
  fi
  
  # Se houver dependências faltando, tenta instalar
  if [ ${#missing_deps[@]} -gt 0 ]; then
    echo -e "${ORANGE}⚠️  Dependências faltando: ${missing_deps[*]}${NC}"
    echo -e "${YELLOW}Deseja instalar as dependências necessárias? [S/n]: ${NC}"
    read -r response
    
    if [[ "$response" =~ ^[Ss]$ ]] || [[ -z "$response" ]]; then
      echo -e "${CYAN}🔧 Instalando dependências...${NC}"
      
      # Atualiza lista de pacotes
      if ! sudo apt-get update >/dev/null 2>&1; then
        echo -e "${RED}❌ Erro ao atualizar lista de pacotes. Execute manualmente: sudo apt-get update${NC}"
        exit 1
      fi
      
      # Instala dependências
      for dep in "${missing_deps[@]}"; do
        echo -e "${CYAN}   Instalando $dep...${NC}"
        if sudo apt-get install -y "$dep" >/dev/null 2>&1; then
          echo -e "${GREEN}   ✅ $dep instalado com sucesso${NC}"
        else
          echo -e "${RED}   ❌ Erro ao instalar $dep${NC}"
          if [ "$dep" = "docker.io" ]; then
            echo -e "${ORANGE}   Para instalar Docker manualmente, execute:${NC}"
            echo -e "${ORANGE}   sudo apt-get update && sudo apt-get install -y docker.io${NC}"
            echo -e "${ORANGE}   sudo systemctl start docker${NC}"
            echo -e "${ORANGE}   sudo usermod -aG docker \$USER${NC}"
            exit 1
          fi
        fi
      done
      
      # Verifica se Docker foi instalado e está rodando
      if [[ " ${missing_deps[*]} " =~ docker.io ]]; then
        echo -e "${CYAN}🔧 Iniciando serviço Docker...${NC}"
        sudo systemctl start docker 2>/dev/null || true
        sudo systemctl enable docker 2>/dev/null || true
        
        # Adiciona usuário ao grupo docker
        if ! groups | grep -q docker; then
          echo -e "${CYAN}🔧 Adicionando usuário ao grupo docker...${NC}"
          sudo usermod -aG docker "$USER"
          echo -e "${ORANGE}⚠️  Para usar Docker sem sudo, você precisa fazer logout e login novamente.${NC}"
          echo -e "${ORANGE}   Ou execute: newgrp docker${NC}"
        fi
      fi
      
      echo -e "${GREEN}✅ Todas as dependências foram instaladas!${NC}\n"
    else
      echo -e "${ORANGE}⚠️  Instalação cancelada. O script pode não funcionar corretamente.${NC}"
      
      # Lista dependências que precisam ser instaladas manualmente
      if [[ " ${missing_deps[*]} " =~ docker.io ]]; then
        echo -e "${ORANGE}   Docker é obrigatório. Instale com: sudo apt-get install docker.io${NC}"
        exit 1
      fi
    fi
  fi
  
  # Verifica se Docker está rodando (se instalado)
  if command -v docker >/dev/null 2>&1; then
    if ! docker info >/dev/null 2>&1; then
      echo -e "${ORANGE}⚠️  Docker está instalado mas não está rodando.${NC}"
      echo -e "${YELLOW}Deseja iniciar o serviço Docker? [S/n]: ${NC}"
      read -r response
      
      if [[ "$response" =~ ^[Ss]$ ]] || [[ -z "$response" ]]; then
        sudo systemctl start docker
        echo -e "${GREEN}✅ Docker iniciado com sucesso${NC}\n"
      else
        echo -e "${RED}❌ Docker não está rodando. O script não pode continuar.${NC}"
        exit 1
      fi
    fi
  fi
}

# Executa verificação de dependências (pula se estiver em container ou variável setada)
if [[ -z "${SKIP_DEPENDENCY_CHECK:-}" ]] && [[ ! -f "/.dockerenv" ]]; then
  check_and_install_dependencies
else
  echo -e "${CYAN}ℹ️  Pulando verificação/instalação de dependências (ambiente containerizado ou SKIP_DEPENDENCY_CHECK=1)${NC}"
fi

# Verifica se o usuário passou uma URL
if [ -z "${1:-}" ]; then
  echo -e "${RED}Uso: $0 <URL>${NC}"
  exit 1
fi

URL="$1"

# Validação da URL no formato http(s)://<fqdn>
if [[ ! "$URL" =~ ^https?://([a-zA-Z0-9.-]+\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(/.*)?$ ]]; then
  echo -e "${RED}Erro: URL inválida. Use o formato http(s)://<domínio> (ex: https://devopsvanilla.guru)${NC}"
  exit 2
fi

# Extrai o FQDN da URL
FQDN=$(echo "$URL" | sed -E 's|https?://([^/:]+).*|\1|')

# Gera timestamp
TIMESTAMP=$(date +"%Y%m%d%H%M")

# Cria pasta de resultados
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/zap-results"
mkdir -p "$RESULTS_DIR"

# Caminho do relatório
HTML_REPORT="${RESULTS_DIR}/${FQDN}-${TIMESTAMP}.html"
PDF_REPORT="${RESULTS_DIR}/${FQDN}-${TIMESTAMP}.pdf"
ZAP_OUTPUT_LOG="${RESULTS_DIR}/${FQDN}-${TIMESTAMP}.log"

# Função para extrair entradas do /etc/hosts para o domínio alvo
get_host_entries() {
  local domain="$1"
  local entries=""
  local found=false
  
  # Procura entradas no /etc/hosts que correspondem ao domínio
  if [ -f /etc/hosts ]; then
    while IFS= read -r line; do
      # Ignora comentários e linhas vazias
      [[ "$line" =~ ^\s*# ]] && continue
      [[ -z "$line" ]] && continue
      
      # Verifica se a linha contém o domínio
      if echo "$line" | grep -qw "$domain"; then
        # Extrai IP e hostname
        local ip=$(echo "$line" | awk '{print $1}')
        local hostname=$(echo "$line" | awk '{print $2}')
        
        if [ -n "$ip" ] && [ -n "$hostname" ]; then
          entries="${entries} --add-host=${hostname}:${ip}"
          # Envia mensagem informativa para stderr (não capturada pela atribuição)
          echo -e "${CYAN}🔗 Mapeamento DNS detectado: ${hostname} -> ${ip}${NC}" >&2
          found=true
        fi
      fi
    done < /etc/hosts
  fi
  
  # Se não encontrou entradas, informa ao usuário (stderr)
  if [ "$found" = false ]; then
    echo -e "${YELLOW}⚠️  Nenhuma entrada encontrada em /etc/hosts para: ${domain}${NC}" >&2
    echo -e "${YELLOW}   Se o domínio não está no DNS público, adicione:${NC}" >&2
    echo -e "${YELLOW}   echo \"<IP> ${domain}\" | sudo tee -a /etc/hosts${NC}" >&2
  fi
  
  # Retorna apenas o valor (stdout)
  echo "$entries"
}

# Função para executar o baseline com uma imagem específica
run_scan_with_image() {
  local image="$1"
  echo -e "${CYAN}📦 Usando imagem: $image${NC}"

  # Se DRY_RUN estiver setado, simula geração do relatório
  if [[ -n "${DRY_RUN:-}" ]]; then
    echo -e "${CYAN}🧪 DRY_RUN ativo - simulando scan e criando HTML fictício${NC}"
    cat >"$HTML_REPORT" <<'EOF'
<!DOCTYPE html><html><head><meta charset="utf-8"><title>ZAP Baseline Report (DRY RUN)</title></head><body><h1>ZAP Baseline Report (DRY RUN)</h1><p>Este é um relatório de teste.</p></body></html>
EOF
    echo "FAIL-NEW: 0     FAIL-INPROG: 0  WARN-NEW: 5    WARN-INPROG: 0  INFO: 0 IGNORE: 0       PASS: 10" > "$ZAP_OUTPUT_LOG"
    return 0
  fi

  # Garante que o Docker está disponível
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker não encontrado. Instale e tente novamente.${NC}"
    return 1
  fi

  if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker não está rodando ou o usuário não tem permissão (verifique 'docker ps').${NC}"
    return 1
  fi

  # Extrai entradas do /etc/hosts para o domínio
  local host_entries=$(get_host_entries "$FQDN")
  
  # Garante permissões corretas no diretório de resultados
  # O container roda como usuário 'zap' (UID 1000), precisa de permissão de escrita
  chmod 777 "$RESULTS_DIR" 2>/dev/null || true
  
  # Garante que arquivos já existentes também tenham permissões corretas
  find "$RESULTS_DIR" -type f -exec chmod 666 {} \; 2>/dev/null || true
  find "$RESULTS_DIR" -type d -exec chmod 777 {} \; 2>/dev/null || true

  echo -e "${CYAN}🔍 Executando scan de segurança em: $URL${NC}"
  
  # Determina modo de rede
  local network_mode="${NETWORK_MODE:-internet}"
  
  if [ "$network_mode" = "local" ]; then
    echo -e "${CYAN}🌐 Modo: Local/Dummy Access (usando rede do host)${NC}"
  else
    echo -e "${CYAN}🌐 Modo: Internet Access${NC}"
  fi
  
  set +e
  
  # Constrói comando Docker baseado no modo de rede
  if [ "$network_mode" = "local" ]; then
    # Modo local: usa network host, não precisa --add-host
    docker run --rm \
      --network host \
      -v "$RESULTS_DIR:/zap/wrk:rw" \
      -u zap \
      -t "$image" zap-baseline.py \
      -t "$URL" \
      -r "$(basename "$HTML_REPORT")" 2>&1 | tee "$ZAP_OUTPUT_LOG"
  else
    # Modo internet: usa --add-host se necessário
    if [ -n "$host_entries" ]; then
      docker run --rm \
        -v "$RESULTS_DIR:/zap/wrk:rw" \
        -u zap \
        $host_entries \
        -t "$image" zap-baseline.py \
        -t "$URL" \
        -r "$(basename "$HTML_REPORT")" 2>&1 | tee "$ZAP_OUTPUT_LOG"
    else
      docker run --rm \
        -v "$RESULTS_DIR:/zap/wrk:rw" \
        -u zap \
        -t "$image" zap-baseline.py \
        -t "$URL" \
        -r "$(basename "$HTML_REPORT")" 2>&1 | tee "$ZAP_OUTPUT_LOG"
    fi
  fi
  
  local rc=$?
  set -e
  return $rc
}

# Seleção da imagem ZAP (não interativa se variáveis de ambiente definidas)
if [[ -n "${ZAP_IMAGE:-}" ]]; then
  if [[ "$ZAP_IMAGE" == "DRY_RUN" ]]; then
    DRY_RUN=1
    echo -e "${CYAN}🧪 DRY_RUN habilitado via ZAP_IMAGE=DRY_RUN${NC}"
  fi
elif [[ -n "${NO_PROMPT:-}" || -n "${CI:-}" || -f "/.dockerenv" ]]; then
  # Modo não interativo: escolhe padrão estável
  ZAP_IMAGE="ghcr.io/zaproxy/zaproxy:stable"
  echo -e "${CYAN}ℹ️  Modo não interativo detectado. Usando imagem padrão: ${ZAP_IMAGE}${NC}"
else
  # Pergunta ao usuário qual imagem deseja usar
  echo -e "${YELLOW}Escolha a imagem Docker para executar o scan ZAP:${NC}"
  echo -e "${YELLOW}1) ghcr.io/zaproxy/zaproxy:stable (GHCR, mais recente)${NC}"
  echo -e "${YELLOW}2) zaproxy/zap-stable (Docker Hub, estável)${NC}"
  echo -e "${YELLOW}3) zaproxy/zap-weekly (Docker Hub, semanal)${NC}"
  echo -e "${YELLOW}4) DRY_RUN (simulação, sem Docker)${NC}"
  echo -e -n "${YELLOW}Digite o número da opção desejada [1-4]: ${NC}"
  read ZAP_OPT

  case "$ZAP_OPT" in
    1)
      ZAP_IMAGE="ghcr.io/zaproxy/zaproxy:stable"
      ;;
    2)
      ZAP_IMAGE="zaproxy/zap-stable"
      ;;
    3)
      ZAP_IMAGE="zaproxy/zap-weekly"
      ;;
    4)
      DRY_RUN=1
      ;;
    *)
      echo -e "${RED}Opção inválida. Abortando.${NC}"
      exit 10
      ;;
  esac
fi

# Seleção do modo de rede (se não definido via variável de ambiente)
if [[ -z "${NETWORK_MODE:-}" ]]; then
  if [[ -n "${NO_PROMPT:-}" || -n "${CI:-}" || -f "/.dockerenv" ]]; then
    # Modo não interativo: verifica se há entrada no /etc/hosts
    if grep -qw "$FQDN" /etc/hosts 2>/dev/null; then
      NETWORK_MODE="local"
      echo -e "${CYAN}ℹ️  Entrada encontrada em /etc/hosts. Usando modo: Local/Dummy Access${NC}"
    else
      NETWORK_MODE="internet"
      echo -e "${CYAN}ℹ️  Usando modo: Internet Access${NC}"
    fi
  else
    # Modo interativo: pergunta ao usuário
    echo -e "${YELLOW}Escolha o modo de acesso à URL:${NC}"
    echo -e "${YELLOW}1) Internet Access (URL acessível via DNS público/internet)${NC}"
    echo -e "${YELLOW}2) Local/Dummy Access (URL local, usa /etc/hosts e rede do host)${NC}"
    echo -e -n "${YELLOW}Digite o número da opção [1-2]: ${NC}"
    read NET_OPT
    
    case "$NET_OPT" in
      1)
        NETWORK_MODE="internet"
        ;;
      2)
        NETWORK_MODE="local"
        ;;
      *)
        echo -e "${ORANGE}Opção inválida. Usando padrão: Internet Access${NC}"
        NETWORK_MODE="internet"
        ;;
    esac
  fi
fi

# Executa o scan com a imagem escolhida
# Captura o exit code mas não para o script (ZAP retorna 0=sucesso, 1=warnings, 2=erros, 3=falha fatal)
set +e
if [[ -n "${DRY_RUN:-}" ]]; then
  run_scan_with_image "dummy"
  ZAP_EXIT_CODE=$?
else
  run_scan_with_image "$ZAP_IMAGE"
  ZAP_EXIT_CODE=$?
fi
set -e

# Verifica se o relatório HTML foi gerado
if [ ! -f "$HTML_REPORT" ]; then
  echo -e "${RED}❌ Erro: Relatório HTML não foi gerado${NC}"
  echo -e "${ORANGE}Dicas de troubleshooting:${NC}"
  echo -e "${ORANGE}  - Verifique conectividade com os registries (ghcr.io, registry-1.docker.io)${NC}"
  echo -e "${ORANGE}  - Se estiver atrás de proxy, exporte HTTP_PROXY/HTTPS_PROXY para o Docker${NC}"
  echo -e "${ORANGE}  - Em ambientes corporativos, o acesso ao GHCR pode ser bloqueado (use 'zaproxy/zap-stable')${NC}"
  echo -e "${ORANGE}  - Você pode escolher a imagem definindo ZAP_IMAGE=...${NC}"
  exit 4
fi

echo -e "${GREEN}✅ Relatório HTML gerado em: $HTML_REPORT${NC}"

# Converte HTML para PDF usando wkhtmltopdf
PDF_GENERATED=0
if command -v wkhtmltopdf >/dev/null 2>&1; then
  set +e
  wkhtmltopdf "$HTML_REPORT" "$PDF_REPORT" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Relatório PDF gerado em: $PDF_REPORT${NC}"
    PDF_GENERATED=1
  else
    echo -e "${ORANGE}⚠️  Erro ao gerar PDF com wkhtmltopdf.${NC}"
  fi
  set -e
else
  echo -e "${ORANGE}⚠️  wkhtmltopdf não está instalado. Apenas o relatório HTML foi gerado.${NC}"
  echo -e "${ORANGE}   Para gerar PDF, instale com: sudo apt install wkhtmltopdf${NC}"
fi

# Extrai estatísticas do relatório HTML
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}               RESUMO DO SCAN DE SEGURANÇA${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Extrai informações da linha de resumo do ZAP (formato: FAIL-NEW: 0 FAIL-INPROG: 0 WARN-NEW: 11...)
if [ -f "$ZAP_OUTPUT_LOG" ]; then
  # Extrai a última linha que contém o resumo
  SUMMARY_LINE=$(grep -E "FAIL-NEW:.*WARN-NEW:.*PASS:" "$ZAP_OUTPUT_LOG" 2>/dev/null | tail -1)
  
  if [ -n "$SUMMARY_LINE" ]; then
    # Extrai cada valor usando regex
    FAIL_COUNT=$(echo "$SUMMARY_LINE" | grep -oP 'FAIL-NEW:\s*\K\d+' || echo "0")
    WARN_COUNT=$(echo "$SUMMARY_LINE" | grep -oP 'WARN-NEW:\s*\K\d+' || echo "0")
    PASS_COUNT=$(echo "$SUMMARY_LINE" | grep -oP 'PASS:\s*\K\d+' || echo "0")
  else
    # Fallback: tenta extrair do HTML
    PASS_COUNT=$(grep -oP 'PASS: \K\d+' "$HTML_REPORT" 2>/dev/null | tail -1 || echo "0")
    WARN_COUNT=$(grep -oP 'WARN-NEW: \K\d+' "$HTML_REPORT" 2>/dev/null | tail -1 || echo "0")
    FAIL_COUNT=$(grep -oP 'FAIL-NEW: \K\d+' "$HTML_REPORT" 2>/dev/null | tail -1 || echo "0")
  fi
  
  # Calcula total de testes
  TOTAL_TESTS=$((PASS_COUNT + WARN_COUNT + FAIL_COUNT))
  
  echo -e "${CYAN}🎯 Total de testes executados:${NC} ${BLUE}$TOTAL_TESTS${NC}"
  echo -e "${GREEN}✅ Testes aprovados (PASS):${NC}    ${GREEN}$PASS_COUNT${NC}"
  echo -e "${ORANGE}⚠️  Alertas encontrados (WARN):${NC}  ${ORANGE}$WARN_COUNT${NC}"
  echo -e "${RED}❌ Falhas detectadas (FAIL):${NC}   ${RED}$FAIL_COUNT${NC}"
  echo ""
  
  # Barra de progresso visual
  if [ "$TOTAL_TESTS" -gt 0 ]; then
    PASS_PERCENT=$((PASS_COUNT * 100 / TOTAL_TESTS))
    WARN_PERCENT=$((WARN_COUNT * 100 / TOTAL_TESTS))
    FAIL_PERCENT=$((FAIL_COUNT * 100 / TOTAL_TESTS))
    
    echo -e "${CYAN}📊 Distribuição:${NC}"
    
    # Cria barra de 50 caracteres
    BAR_LENGTH=50
    PASS_BAR=$((PASS_COUNT * BAR_LENGTH / TOTAL_TESTS))
    WARN_BAR=$((WARN_COUNT * BAR_LENGTH / TOTAL_TESTS))
    FAIL_BAR=$((FAIL_COUNT * BAR_LENGTH / TOTAL_TESTS))
    
    printf "   "
    printf "${GREEN}"
    printf '█%.0s' $(seq 1 $PASS_BAR) 2>/dev/null
    printf "${ORANGE}"
    printf '█%.0s' $(seq 1 $WARN_BAR) 2>/dev/null
    printf "${RED}"
    printf '█%.0s' $(seq 1 $FAIL_BAR) 2>/dev/null
    printf "${NC}"
    printf '░%.0s' $(seq 1 $((BAR_LENGTH - PASS_BAR - WARN_BAR - FAIL_BAR))) 2>/dev/null
    printf "${NC}\n"
    
    echo -e "   ${GREEN}■${NC} Pass: ${PASS_PERCENT}%  ${ORANGE}■${NC} Warn: ${WARN_PERCENT}%  ${RED}■${NC} Fail: ${FAIL_PERCENT}%"
  fi
fi

echo ""
echo -e "${CYAN}📄 Relatórios gerados:${NC}"
echo -e "   ${BLUE}HTML:${NC} $HTML_REPORT"
if [ "$PDF_GENERATED" -eq 1 ]; then
  echo -e "   ${BLUE}PDF:${NC}  $PDF_REPORT"
fi
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Retorna o exit code original do ZAP
exit "${ZAP_EXIT_CODE:-0}"