#!/usr/bin/env bash

set -euo pipefail

# Cores para formatação ANSI (Melhoria de UX)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sem Cor

clear

# Verificações de segurança das ferramentas necessárias (Blocos tradicionais mais robustos)
if ! command -v gcloud >/dev/null 2>&1; then
    echo -e "${RED}❌ Erro: gcloud CLI não encontrado. Instale o Google Cloud SDK.${NC}" >&2
    exit 1
fi

if ! command -v bq >/dev/null 2>&1; then
    echo -e "${RED}❌ Erro: bq CLI do BigQuery não encontrado.${NC}" >&2
    exit 1
fi

# Definição do Projeto GCP
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || echo '')}"
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}❌ Erro: Projeto GCP não configurado no gcloud. Execute 'gcloud config set project ID' ou exporte PROJECT_ID.${NC}" >&2
    exit 1
fi

# Configurações padrões (Podem ser sobrescritas por variáveis de ambiente)
DATASET_ID="${DATASET_ID:-billing_export}"
START=""
END=""

usage() {
    cat <<EOF
Uso: $0 [--start "YYYY-MM-DD HH:MM:SS"] [--end "YYYY-MM-DD HH:MM:SS"]

O arquivo CSV será gerado automaticamente na pasta 'output' seguindo o padrão de nomenclatura da equipe.
EOF
}

# Tratamento dinâmico de argumentos de entrada
while [[ $# -gt 0 ]]; do
    case "$1" in
        --start) START="$2"; shift 2;;
        --end) END="$2"; shift 2;;
        -h|--help) usage; exit 0;;
        *) echo -e "${RED}❌ Argumento desconhecido: $1${NC}" >&2; usage; exit 1;;
    esac
done

# Definição de datas automáticas se vazias
if [ -z "$START" ] || [ -z "$END" ]; then
    END="$(date -u +"%Y-%m-%d %H:00:00")"
    START="$(date -u -d '24 hours ago' +"%Y-%m-%d %H:00:00")"
fi

# 1. Extração e formatação das datas para o padrão YYYYMMDDHHMMSS
START_COMPACT=$(echo "$START" | tr -cd '0-9')
END_COMPACT=$(echo "$END" | tr -cd '0-9')

# 2. Criação da pasta 'output' caso ela não exista
mkdir -p output

# 3. Definição do caminho dinâmico do arquivo de saída
OUTFILE="output/gcloud-billing-${START_COMPACT}-${END_COMPACT}.csv"

echo -e "${BLUE}🚀 Iniciando Automação de Exportação de Faturamento por Hora...${NC}"
echo -e "${BLUE}📋 Projeto Ativo:${NC} $PROJECT_ID"
echo -e "${BLUE}📋 Dataset Alvo: ${NC} $DATASET_ID"
echo -e "${BLUE}📋 Período (UTC):${NC} $START até $END"
echo -e "${BLUE}📋 Destino CSV:${NC}  $OUTFILE"
echo -e "${BLUE}------------------------------------------------------------${NC}"

# Validar a existência física do Dataset no projeto
if ! bq --project_id="$PROJECT_ID" show --format=prettyjson "$DATASET_ID" >/dev/null 2>&1; then
    echo -e "${RED}❌ Erro: O dataset '$DATASET_ID' não foi localizado no projeto '$PROJECT_ID'.${NC}" >&2
    exit 1
fi

# Busca inteligente pelas tabelas de Billing (Priorizando Custo Detalhado por Recurso)
echo -e "${YELLOW}🔍 Vasculhando tabelas de faturamento no BigQuery...${NC}"

# Procura primeiro pelo formato detalhado por recurso
TABLE_FOUND=$(bq ls --max_results=200 --project_id="$PROJECT_ID" "$DATASET_ID" | grep "gcp_billing_export_resource_v1_" | awk '{print $1}' | head -n 1 || true)

if [ -z "$TABLE_FOUND" ]; then
    echo -e "${YELLOW}⚠️  Tabela detalhada por recurso não encontrada. Procurando tabela padrão...${NC}"
    # Fallback para o formato padrão
    TABLE_FOUND=$(bq ls --max_results=200 --project_id="$PROJECT_ID" "$DATASET_ID" | grep "gcp_billing_export_v1_" | awk '{print $1}' | head -n 1 || true)
fi

# Se nenhuma das duas tabelas existir, aborta com instruções amigáveis
if [ -z "$TABLE_FOUND" ]; then
    echo -e "\n${RED}❌ Erro Crítico: Nenhuma tabela de faturamento ativa foi encontrada em '$DATASET_ID'.${NC}"
    echo -e "${YELLOW}💡 Próximos Passos Obrigatórios:${NC}"
    echo -e "   1. Vá no Console GCP -> Faturamento -> Exportação do Faturamento."
    echo -e "   2. Ative o card 'Custo de uso detalhado' apontando para o dataset '$DATASET_ID'."
    echo -e "   3. Lembre-se: O GCP leva de 24 a 48 horas para provisionar a primeira tabela após o clique.\n"
    exit 1
fi

echo -e "${GREEN}✅ Tabela identificada com sucesso: $TABLE_FOUND${NC}"

# Montagem dinâmica da Query com base no Schema da tabela encontrada
if [[ "$TABLE_FOUND" == *resource* ]]; then
    echo -e "${GREEN}📊 Modo de Alta Granularidade Ativado (Dados por Recurso Individual).${NC}"
    RESOURCE_SELECT="resource.name AS resource_name"
    RESOURCE_GROUP="resource_name"
else
    echo -e "${YELLOW}⚠️  Modo Padrão Ativado (Dados apenas por Projeto/Serviço - Sem ID de Recursos).${NC}"
    RESOURCE_SELECT="'N/A' AS resource_name"
    RESOURCE_GROUP="resource_name"
fi

echo -e "${BLUE}⚙️  Disparando consulta analítica otimizada no BigQuery...${NC}"

read -r -d '' query <<EOF || true
SELECT
    TIMESTAMP_TRUNC(usage_start_time, HOUR) AS hour,
    project.id AS project_id,
    service.description AS service,
    sku.description AS sku,
    $RESOURCE_SELECT,
    SUM(cost) AS total_cost
FROM
    \`$PROJECT_ID.$DATASET_ID.$TABLE_FOUND\`
WHERE usage_start_time >= TIMESTAMP("$START")
  AND usage_start_time < TIMESTAMP("$END")
GROUP BY hour, project_id, service, sku, $RESOURCE_GROUP
ORDER BY hour, project_id, $RESOURCE_GROUP;
EOF

# Executa no BigQuery e extrai diretamente em formato CSV limpo
bq --project_id="$PROJECT_ID" query --nouse_legacy_sql --format=csv --quiet "$query" > "$OUTFILE"

# Validação de integridade do Arquivo Gerado
if [ -f "$OUTFILE" ]; then
    if [ ! -s "$OUTFILE" ]; then
        echo -e "${YELLOW}⚠️  Atenção: Consulta executada com sucesso, mas retornou 0 linhas de dados para o período selecionado.${NC}"
    else
        total_lines=$(wc -l < "$OUTFILE" | tr -d '[:space:]')
        data_lines=$((total_lines - 1))
        echo -e "${GREEN}✨ Sucesso absoluto! Dados consolidados salvos em: $OUTFILE${NC}"
        echo -e "${GREEN}📊 Total de registros faturados por hora extraídos: $data_lines${NC}"
    fi
else
    echo -e "${RED}❌ Erro inesperado: Falha na criação física do arquivo de saída.${NC}" >&2
    exit 1
fi

exit 0
