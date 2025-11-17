#!/bin/bash
set -euo pipefail

# Definição de cores
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}        OWASP ZAP Scanner - Execução Containerizada${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Verificar se Docker está instalado e rodando
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker não encontrado. Instale o Docker e tente novamente.${NC}"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker não está rodando. Inicie o serviço Docker:${NC}"
    echo -e "${ORANGE}   sudo systemctl start docker${NC}"
    exit 1
fi

# Verificar se a imagem já existe
IMAGE_EXISTS=false
if docker images | grep -q "zap-scanner"; then
    IMAGE_EXISTS=true
fi

# Perguntar sobre build/rebuild
if [ "$IMAGE_EXISTS" = true ]; then
    echo -e "${YELLOW}🔍 Imagem 'zap-scanner' já existe.${NC}"
    echo -e "${YELLOW}Deseja reconstruir a imagem? [s/N]: ${NC}"
    read -r rebuild_response
    
    if [[ "$rebuild_response" =~ ^[Ss]$ ]]; then
        echo -e "${CYAN}🔨 Reconstruindo imagem Docker...${NC}"
        if docker build -t zap-scanner . >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Imagem reconstruída com sucesso${NC}\n"
        else
            echo -e "${RED}❌ Erro ao reconstruir imagem${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✅ Usando imagem existente${NC}\n"
    fi
else
    echo -e "${CYAN}🔨 Construindo imagem Docker pela primeira vez...${NC}"
    if docker build -t zap-scanner . 2>&1 | grep -E "(Step|Successfully|naming to)"; then
        echo -e "${GREEN}✅ Imagem construída com sucesso${NC}\n"
    else
        echo -e "${RED}❌ Erro ao construir imagem${NC}"
        exit 1
    fi
fi

# Solicitar URL alvo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}🎯 URL do alvo para scan de segurança${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
echo -e "${ORANGE}Formato: http(s)://<domínio> (ex: https://devopsvanilla.guru)${NC}"
echo -e -n "${YELLOW}Digite a URL: ${NC}"
read -r TARGET_URL

# Validação básica da URL
if [[ ! "$TARGET_URL" =~ ^https?://([a-zA-Z0-9.-]+\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(/.*)?$ ]]; then
    echo -e "${RED}❌ URL inválida. Use o formato http(s)://<domínio>${NC}"
    exit 2
fi

echo -e "${GREEN}✅ URL válida: $TARGET_URL${NC}\n"

# Escolher imagem ZAP
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📦 Escolha a imagem do OWASP ZAP${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
echo -e "${YELLOW}1) ghcr.io/zaproxy/zaproxy:stable ${BLUE}(GHCR, mais recente)${NC}"
echo -e "${YELLOW}2) zaproxy/zap-stable ${BLUE}(Docker Hub, estável - recomendado)${NC}"
echo -e "${YELLOW}3) zaproxy/zap-weekly ${BLUE}(Docker Hub, semanal)${NC}"
echo -e "${YELLOW}4) DRY_RUN ${BLUE}(simulação rápida, sem scan real)${NC}"
echo -e -n "${YELLOW}Digite o número da opção [1-4]: ${NC}"
read -r ZAP_OPTION

case "$ZAP_OPTION" in
    1)
        ZAP_IMAGE="ghcr.io/zaproxy/zaproxy:stable"
        echo -e "${GREEN}✅ Selecionado: GHCR estável${NC}\n"
        ;;
    2)
        ZAP_IMAGE="zaproxy/zap-stable"
        echo -e "${GREEN}✅ Selecionado: Docker Hub estável${NC}\n"
        ;;
    3)
        ZAP_IMAGE="zaproxy/zap-weekly"
        echo -e "${GREEN}✅ Selecionado: Docker Hub semanal${NC}\n"
        ;;
    4)
        ZAP_IMAGE="DRY_RUN"
        echo -e "${GREEN}✅ Selecionado: Modo simulação (DRY_RUN)${NC}\n"
        ;;
    *)
        echo -e "${RED}❌ Opção inválida. Usando padrão: zaproxy/zap-stable${NC}\n"
        ZAP_IMAGE="zaproxy/zap-stable"
        ;;
esac

# Pergunta sobre ambiente de produção
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}⚠️  AVISO DE SEGURANÇA${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
echo -e "${ORANGE}Esta URL está em ambiente de PRODUÇÃO?${NC}"
echo -e "${ORANGE}(com WAF, IDS/IPS, SIEM, CDN ativo)${NC}\n"
echo -e -n "${YELLOW}[s/N]: ${NC}"
read -r PROD_ENV

if [[ "$PROD_ENV" =~ ^[Ss]$ ]]; then
    echo -e "\n${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}⚠️  ATENÇÃO: SCAN EM PRODUÇÃO${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "${ORANGE}Scans em produção podem causar:${NC}"
    echo -e "${ORANGE}  • Bloqueio de IP${NC}"
    echo -e "${ORANGE}  • Alertas de segurança (WAF/IDS/IPS/SIEM)${NC}"
    echo -e "${ORANGE}  • Rate limiting da CDN${NC}"
    echo -e "${ORANGE}  • Escalação para equipes de segurança${NC}\n"
    echo -e "${YELLOW}Você obteve AUTORIZAÇÃO FORMAL dos times de:${NC}"
    echo -e "${YELLOW}  • Segurança da Informação${NC}"
    echo -e "${YELLOW}  • Monitoramento (NOC/SOC)${NC}"
    echo -e "${YELLOW}  • E possui número de chamado/ticket?${NC}\n"
    echo -e -n "${RED}Confirma que possui autorização? [s/N]: ${NC}"
    read -r AUTH_CONFIRM
    
    if [[ ! "$AUTH_CONFIRM" =~ ^[Ss]$ ]]; then
        echo -e "\n${RED}❌ Scan cancelado. Obtenha autorização antes de continuar.${NC}"
        echo -e "${ORANGE}💡 Dica: Use ambientes de staging/desenvolvimento para testes.${NC}"
        exit 3
    fi
    
    echo -e -n "\n${YELLOW}Número do chamado/ticket de autorização: ${NC}"
    read -r TICKET_NUMBER
    
    if [ -z "$TICKET_NUMBER" ]; then
        echo -e "${ORANGE}⚠️  Prosseguindo sem número de ticket (não recomendado)${NC}\n"
    else
        echo -e "${GREEN}✅ Ticket registrado: $TICKET_NUMBER${NC}\n"
    fi
fi

# Criar diretório de resultados
mkdir -p "$SCRIPT_DIR/zap-results"

# Resumo antes da execução
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}        RESUMO DA CONFIGURAÇÃO${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
echo -e "${BLUE}URL alvo:${NC}        $TARGET_URL"
echo -e "${BLUE}Imagem ZAP:${NC}      $ZAP_IMAGE"
echo -e "${BLUE}Resultados:${NC}      $SCRIPT_DIR/zap-results/"
if [ -n "${TICKET_NUMBER:-}" ]; then
    echo -e "${BLUE}Ticket:${NC}          $TICKET_NUMBER"
fi
echo -e "\n${YELLOW}Pressione ENTER para iniciar o scan ou CTRL+C para cancelar${NC}"
read -r

# Executar o container
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}        INICIANDO SCAN DE SEGURANÇA${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Construir comando Docker
DOCKER_CMD="docker run --rm \
  -e ZAP_IMAGE=$ZAP_IMAGE \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $SCRIPT_DIR/zap-results:/app/zap-results \
  --privileged \
  zap-scanner $TARGET_URL"

# Executar
set +e
eval "$DOCKER_CMD"
EXIT_CODE=$?
set -e

# Resultado final
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}        SCAN FINALIZADO${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Scan concluído com sucesso!${NC}\n"
elif [ $EXIT_CODE -eq 1 ]; then
    echo -e "${ORANGE}⚠️  Scan concluído com warnings${NC}\n"
elif [ $EXIT_CODE -eq 2 ]; then
    echo -e "${ORANGE}⚠️  Scan concluído com alertas de segurança${NC}\n"
else
    echo -e "${RED}❌ Scan finalizado com erros (exit code: $EXIT_CODE)${NC}\n"
fi

# Listar arquivos gerados
echo -e "${BLUE}📁 Arquivos gerados em zap-results/:${NC}\n"
ls -lht "$SCRIPT_DIR/zap-results/" | head -6

echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Para visualizar os relatórios:${NC}"
echo -e "${YELLOW}  HTML: xdg-open zap-results/<arquivo>.html${NC}"
echo -e "${YELLOW}  PDF:  xdg-open zap-results/<arquivo>.pdf${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

exit $EXIT_CODE
