#!/usr/bin/env bash
# ==============================================================================
# Script: remove-billable-resources.sh
# Objetivo: Identificar e remover (com confirmação explícita) recursos tarifáveis
#           (não gratuitos) em TODOS os projetos ou em projetos específicos
#           conectados à conta Google Cloud.
#
# Destaques:
#   - Identificação automática de todos os projetos ativos da conta GCP
#   - Mensagens de acompanhamento em tempo real indicando onde cada recurso foi encontrado
#   - Relatório de Pré-Flight detalhado agrupado por projeto e localização
#   - Confirmação explícita antes de qualquer ação destrutiva
#   - Execução ordenada com polling ativo de confirmação de exclusão
#   - Relatório final pós-execução consolidado por projeto
# ==============================================================================

set -uo pipefail

# ------------------------------------------------------------------------------
# Cores e Estilos para Saída
# ------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ------------------------------------------------------------------------------
# Variáveis Globais
# ------------------------------------------------------------------------------
TARGET_PROJECT=""
ALL_PROJECTS=false
DRY_RUN=false
AUTO_CONFIRM=false
VERBOSE=false

# Arrays para rastreamento
# Formato: "PROJECT_ID|PROJECT_NAME|SERVICE|RESOURCE_TYPE|NAME|LOCATION|DELETE_CMD|CHECK_CMD"
DISCOVERED_RESOURCES=()
SUCCESS_DELETED=()
FAILED_DELETED=()
PROJECTS_FOUND=()

# ------------------------------------------------------------------------------
# Funções de Log e Ajuda
# ------------------------------------------------------------------------------
log_info()    { echo -e "${CYAN}ℹ [INFO]${RESET} $1"; }
log_step()    { echo -e "${BLUE}▶ [SCAN]${RESET} $1"; }
log_found()   { echo -e "${YELLOW}${BOLD}🔍 [ENCONTRADO]${RESET} ${BOLD}[Proj: $1]${RESET} ${MAGENTA}$2${RESET} ➔ ${BOLD}$3${RESET} (${CYAN}$4${RESET})"; }
log_success() { echo -e "${GREEN}✔ [OK]${RESET} $1"; }
log_warn()    { echo -e "${YELLOW}⚠ [AVISO]${RESET} $1"; }
log_error()   { echo -e "${RED}✖ [ERRO]${RESET} $1"; }
log_header()  {
    echo -e "\n${BOLD}${BLUE}══════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${BLUE}  $1${RESET}"
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════════════════════════════════════════════════════════${RESET}\n"
}

usage() {
    echo -e "${BOLD}USO:${RESET}"
    echo -e "    $(basename "$0") [OPÇÕES]\n"
    echo -e "${BOLD}DESCRIÇÃO:${RESET}"
    echo -e "    Identifica e remove recursos tarifáveis (não gratuitos) nos projetos da conta GCP."
    echo -e "    Exibe mensagens em tempo real indicando exatamente o projeto e localização de cada recurso,"
    echo -e "    apresenta um Pré-Flight completo, exige confirmação antes de executar e valida a remoção.\n"
    echo -e "${BOLD}OPÇÕES:${RESET}"
    echo -e "    -a, --all-projects       Escaneia e remove recursos em TODOS os projetos ativos da conta (Recomendado)"
    echo -e "    -p, --project <ID>       Define um projeto GCP específico para varredura"
    echo -e "    -d, --dry-run            Modo simulação: executa apenas a varredura (Pre-flight) sem deletar nada"
    echo -e "    -y, --yes, --force       Confirma automaticamente as solicitações de exclusão (USE COM CAUTELA)"
    echo -e "    -v, --verbose            Exibe saídas e logs detalhados de depuração"
    echo -e "    -h, --help               Exibe esta mensagem de ajuda\n"
    echo -e "${BOLD}EXEMPLOS:${RESET}"
    echo -e "    # Executa varredura e remoção em TODOS os projetos da conta com pré-flight:"
    echo -e "    ./remove-billable-resources.sh --all-projects\n"
    echo -e "    # Simulação (dry-run) em todos os projetos da conta:"
    echo -e "    ./remove-billable-resources.sh --all-projects --dry-run\n"
    echo -e "    # Executa apenas no projeto atual ativo:"
    echo -e "    ./remove-billable-resources.sh\n"
    echo -e "    # Executa em um projeto específico:"
    echo -e "    ./remove-billable-resources.sh -p meu-projeto-especifico\n"
    exit 0
}

# ------------------------------------------------------------------------------
# Parsing de Argumentos
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--project)
            TARGET_PROJECT="$2"
            shift 2
            ;;
        -a|--all-projects)
            ALL_PROJECTS=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -y|--yes|--force)
            AUTO_CONFIRM=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Opção desconhecida: $1"
            usage
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Validações Iniciais e Autenticação
# ------------------------------------------------------------------------------
check_dependencies() {
    local deps=("gcloud" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            log_error "Dependência necessária não encontrada: $dep"
            exit 1
        fi
    done
}

verify_gcloud_auth() {
    ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null || true)
    if [[ -z "$ACTIVE_ACCOUNT" ]]; then
        log_error "Nenhuma conta ativa encontrada no gcloud. Execute 'gcloud auth login' antes de continuar."
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Descoberta de Projetos na Conta
# ------------------------------------------------------------------------------
discover_projects() {
    log_header "DESCOBERTA DE PROJETOS NA CONTA CONECTADA"
    echo -e "${BOLD}Conta GCP Autenticada:${RESET} ${GREEN}${ACTIVE_ACCOUNT}${RESET}\n"

    local current_active
    current_active=$(gcloud config get-value project 2>/dev/null || true)

    log_info "Identificando projetos acessíveis pela conta..."

    while IFS=$'\t' read -r pid pname state; do
        if [[ -n "$pid" && "$state" == "ACTIVE" ]]; then
            PROJECTS_FOUND+=("${pid}|${pname}")
        fi
    done < <(gcloud projects list --filter="lifecycleState:ACTIVE" --format="value(projectId,name,lifecycleState)" 2>/dev/null || true)

    local total_proj=${#PROJECTS_FOUND[@]}
    if [[ $total_proj -eq 0 ]]; then
        log_warn "Nenhum projeto ativo foi listado via 'gcloud projects list'."
        if [[ -n "$current_active" && "$current_active" != "(unset)" ]]; then
            log_info "Utilizando o projeto ativo configurado: ${current_active}"
            PROJECTS_FOUND+=("${current_active}|${current_active}")
        else
            log_error "Nenhum projeto encontrado. Especifique com -p <PROJECT_ID>."
            exit 1
        fi
    else
        echo -e "${GREEN}${BOLD}✔ Foram identificados ${total_proj} projeto(s) ativos na conta:${RESET}\n"
        local idx=1
        for p_info in "${PROJECTS_FOUND[@]}"; do
            IFS='|' read -r pid pname <<< "$p_info"
            local marker=""
            [[ "$pid" == "$current_active" ]] && marker=" ${YELLOW}(Projeto Ativo)${RESET}"
            printf "  ${BOLD}[%2d]${RESET} %-26s ${DIM}(Nome: %s)${RESET}%b\n" "$idx" "$pid" "$pname" "$marker"
            ((idx++))
        done
        echo ""
    fi

    # Se nenhum parâmetro foi passado e não foi especificado --all-projects nem -p:
    if [[ "$ALL_PROJECTS" == false && -z "$TARGET_PROJECT" ]]; then
        if [[ $total_proj -gt 1 ]]; then
            echo -e "${CYAN}${BOLD}Como você deseja proceder com a varredura?${RESET}"
            echo -e "  ${BOLD}[1]${RESET} Varrer ${BOLD}TODOS OS ${total_proj} PROJETOS${RESET} da conta (Recomendado)"
            echo -e "  ${BOLD}[2]${RESET} Varrer apenas o projeto ativo atual (${CYAN}${current_active}${RESET})"
            echo -e "  ${BOLD}[3]${RESET} Escolher um projeto da lista"
            echo ""
            read -r -p "Escolha uma opção [1-3] (padrão: 1): " CHOICE_OPTION
            CHOICE_OPTION="${CHOICE_OPTION:-1}"

            case "$CHOICE_OPTION" in
                1)
                    ALL_PROJECTS=true
                    log_info "Opção selecionada: Varrer TODOS os projetos da conta."
                    ;;
                2)
                    TARGET_PROJECT="$current_active"
                    log_info "Opção selecionada: Varrer apenas o projeto ativo atual (${TARGET_PROJECT})."
                    ;;
                3)
                    read -r -p "Digite o número do projeto desejado [1-${total_proj}]: " P_NUM
                    if [[ "$P_NUM" =~ ^[0-9]+$ ]] && [[ "$P_NUM" -ge 1 && "$P_NUM" -le "$total_proj" ]]; then
                        local selected_info="${PROJECTS_FOUND[$((P_NUM-1))]}"
                        TARGET_PROJECT="${selected_info%%|*}"
                        log_info "Opção selecionada: Projeto ${TARGET_PROJECT}."
                    else
                        log_warn "Opção inválida. Utilizando todos os projetos."
                        ALL_PROJECTS=true
                    fi
                    ;;
                *)
                    ALL_PROJECTS=true
                    log_info "Opção padrão selecionada: Varrer TODOS os projetos da conta."
                    ;;
            esac
        else
            TARGET_PROJECT="${current_active:-${PROJECTS_FOUND[0]%%|*}}"
        fi
    fi
}

# ------------------------------------------------------------------------------
# Coleta e Identificação de Recursos Tarifáveis por Projeto
# ------------------------------------------------------------------------------
scan_project_resources() {
    local proj="$1"
    local proj_name="$2"

    echo -e "\n${BOLD}${CYAN}──────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
    echo -e "${BOLD}${CYAN}  📂 VARRENDO PROJETO: ${YELLOW}${proj}${RESET} ${DIM}(${proj_name})${RESET}"
    echo -e "${BOLD}${CYAN}──────────────────────────────────────────────────────────────────────────────────────────────${RESET}"

    # Obtém a lista de serviços habilitados uma única vez para o projeto
    local enabled_services
    enabled_services=$(gcloud services list --project="$proj" --enabled --format="value(config.name)" 2>/dev/null || true)

    is_enabled() {
        echo "$enabled_services" | grep -q "^$1$"
    }

    local initial_count=${#DISCOVERED_RESOURCES[@]}

    # 1. GKE Clusters (Cobrança de gestão de cluster + nós de computação)
    if is_enabled "container.googleapis.com"; then
        log_step "[$proj] Checando Google Kubernetes Engine (GKE)..."
        while IFS=$'\t' read -r name loc; do
            if [[ -n "$name" ]]; then
                log_found "$proj" "Kubernetes Engine" "GKE Cluster: ${name}" "$loc"
                DISCOVERED_RESOURCES+=("${proj}|${proj_name}|Kubernetes Engine|GKE Cluster|${name}|${loc}|gcloud container clusters delete ${name} --location=${loc} --project=${proj} --quiet --async|gcloud container clusters describe ${name} --location=${loc} --project=${proj}")
            fi
        done < <(gcloud container clusters list --project="$proj" --format="value(name,location)" 2>/dev/null || true)
    fi

    # 2. Compute Engine (VMs, Discos, Snapshots, IPs Estáticos, Forwarding Rules, Routers, VPNs)
    if is_enabled "compute.googleapis.com"; then
        log_step "[$proj] Checando Compute Engine (VMs, Discos, IPs e Redes)..."

        # VMs
        while IFS=$'\t' read -r name zone mtype status; do
            if [[ -n "$name" ]]; then
                log_found "$proj" "Compute Engine" "VM: ${name} [${mtype}, ${status}]" "$zone"
                DISCOVERED_RESOURCES+=("${proj}|${proj_name}|Compute Engine|VM Instance (${mtype}, ${status})|${name}|${zone}|gcloud compute instances delete ${name} --zone=${zone} --project=${proj} --quiet|gcloud compute instances describe ${name} --zone=${zone} --project=${proj}")
            fi
        done < <(gcloud compute instances list --project="$proj" --format="value(name,zone.basename(),machineType.basename(),status)" 2>/dev/null || true)

        # Discos Persistentes
        while IFS=$'\t' read -r name zone size type in_use; do
            if [[ -n "$name" ]]; then
                local status_desc="${size}GB (${type})"
                [[ -z "$in_use" ]] && status_desc="${status_desc} [Desanexado]"
                log_found "$proj" "Compute Engine" "Disco: ${name} (${status_desc})" "$zone"
                DISCOVERED_RESOURCES+=("${proj}|${proj_name}|Compute Engine|Persistent Disk (${status_desc})|${name}|${zone}|gcloud compute disks delete ${name} --zone=${zone} --project=${proj} --quiet|gcloud compute disks describe ${name} --zone=${zone} --project=${proj}")
            fi
        done < <(gcloud compute disks list --project="$proj" --format="value(name,zone.basename(),sizeGb,type.basename(),users.list())" 2>/dev/null || true)

        # Snapshots
        while IFS=$'\t' read -r name disk_size; do
            if [[ -n "$name" ]]; then
                log_found "$proj" "Compute Engine" "Snapshot: ${name} (${disk_size}GB)" "global"
                DISCOVERED_RESOURCES+=("${proj}|${proj_name}|Compute Engine|Disk Snapshot (${disk_size}GB)|${name}|global|gcloud compute snapshots delete ${name} --project=${proj} --quiet|gcloud compute snapshots describe ${name} --project=${proj}")
            fi
        done < <(gcloud compute snapshots list --project="$proj" --format="value(name,diskSizeGb)" 2>/dev/null || true)

        # Endereços IP Estáticos
        while IFS=$'\t' read -r name reg address status; do
            if [[ -n "$name" ]]; then
                local flag="--region=${reg}"
                [[ "$reg" == "global" || -z "$reg" ]] && flag="--global" && reg="global"
                log_found "$proj" "VPC Network" "IP Estático: ${name} (${address}, ${status})" "$reg"
                DISCOVERED_RESOURCES+=("${proj}|${proj_name}|VPC Network|Static IP (${address}, ${status})|${name}|${reg}|gcloud compute addresses delete ${name} ${flag} --project=${proj} --quiet|gcloud compute addresses describe ${name} ${flag} --project=${proj}")
            fi
        done < <(gcloud compute addresses list --project="$proj" --format="value(name,region.basename(),address,status)" 2>/dev/null || true)

        # Forwarding Rules (Load Balancers)
        while IFS=$'\t' read -r name reg; do
            if [[ -n "$name" ]]; then
                local flag="--region=${reg}"
                [[ "$reg" == "global" || -z "$reg" ]] && flag="--global" && reg="global"
                log_found "$proj" "Cloud Load Balancing" "Forwarding Rule: ${name}" "$reg"
                DISCOVERED_RESOURCES+=("${proj}|${proj_name}|Cloud Load Balancing|Forwarding Rule|${name}|${reg}|gcloud compute forwarding-rules delete ${name} ${flag} --project=${proj} --quiet|gcloud compute forwarding-rules describe ${name} ${flag} --project=${proj}")
            fi
        done < <(gcloud compute forwarding-rules list --project="$proj" --format="value(name,region.basename())" 2>/dev/null || true)

        # Cloud Routers / NAT
        while IFS=$'\t' read -r name reg nats; do
            if [[ -n "$name" ]]; then
                local desc="Cloud Router"
                [[ -n "$nats" && "$nats" != "[]" ]] && desc="Cloud Router + NAT (${nats})"
                log_found "$proj" "VPC Network" "${desc}: ${name}" "$reg"
                DISCOVERED_RESOURCES+=("${proj}|${proj_name}|VPC Network|${desc}|${name}|${reg}|gcloud compute routers delete ${name} --region=${reg} --project=${proj} --quiet|gcloud compute routers describe ${name} --region=${reg} --project=${proj}")
            fi
        done < <(gcloud compute routers list --project="$proj" --format="value(name,region.basename(),nats.name.list())" 2>/dev/null || true)

        # VPN Gateways
        while IFS=$'\t' read -r name reg; do
            if [[ -n "$name" ]]; then
                log_found "$proj" "VPC Network" "VPN Gateway: ${name}" "$reg"
                DISCOVERED_RESOURCES+=("${proj}|${proj_name}|VPC Network|VPN Gateway|${name}|${reg}|gcloud compute vpn-gateways delete ${name} --region=${reg} --project=${proj} --quiet|gcloud compute vpn-gateways describe ${name} --region=${reg} --project=${proj}")
            fi
        done < <(gcloud compute vpn-gateways list --project="$proj" --format="value(name,region.basename())" 2>/dev/null || true)
    fi

    # 3. Cloud SQL
    if is_enabled "sqladmin.googleapis.com"; then
        log_step "[$proj] Checando Cloud SQL..."
        while IFS=$'\t' read -r name reg tier state; do
            if [[ -n "$name" ]]; then
                log_found "$proj" "Cloud SQL" "Instância: ${name} [${tier}, ${state}]" "$reg"
                DISCOVERED_RESOURCES+=("${proj}|${proj_name}|Cloud SQL|SQL Instance (${tier}, ${state})|${name}|${reg}|gcloud sql instances delete ${name} --project=${proj} --quiet|gcloud sql instances describe ${name} --project=${proj}")
            fi
        done < <(gcloud sql instances list --project="$proj" --format="value(name,region,settings.tier,state)" 2>/dev/null || true)
    fi

    # 4. Cloud Run
    if is_enabled "run.googleapis.com"; then
        log_step "[$proj] Checando Cloud Run..."
        while IFS=$'\t' read -r name reg; do
            if [[ -n "$name" ]]; then
                log_found "$proj" "Cloud Run" "Serviço: ${name}" "$reg"
                DISCOVERED_RESOURCES+=("${proj}|${proj_name}|Cloud Run|Run Service|${name}|${reg}|gcloud run services delete ${name} --region=${reg} --project=${proj} --quiet|gcloud run services describe ${name} --region=${reg} --project=${proj}")
            fi
        done < <(gcloud run services list --project="$proj" --format="value(metadata.name,metadata.annotations.run.googleapis.com/location)" 2>/dev/null || true)
    fi

    # 5. Cloud Functions
    if is_enabled "cloudfunctions.googleapis.com"; then
        log_step "[$proj] Checando Cloud Functions..."
        while IFS=$'\t' read -r name reg; do
            if [[ -n "$name" ]]; then
                log_found "$proj" "Cloud Functions" "Função: ${name}" "$reg"
                DISCOVERED_RESOURCES+=("${proj}|${proj_name}|Cloud Functions|Function|${name}|${reg}|gcloud functions delete ${name} --region=${reg} --project=${proj} --quiet|gcloud functions describe ${name} --region=${reg} --project=${proj}")
            fi
        done < <(gcloud functions list --project="$proj" --format="value(name.basename(),name.segment(3))" 2>/dev/null || true)
    fi

    # 6. Cloud Storage (GCS)
    if is_enabled "storage.googleapis.com"; then
        log_step "[$proj] Checando Cloud Storage Buckets..."
        while IFS=$'\t' read -r name loc class; do
            if [[ -n "$name" ]]; then
                log_found "$proj" "Cloud Storage" "Bucket: gs://${name} [${class}]" "$loc"
                DISCOVERED_RESOURCES+=("${proj}|${proj_name}|Cloud Storage|GCS Bucket (${class})|${name}|${loc}|gcloud storage rm --recursive gs://${name} --project=${proj} --quiet|gcloud storage buckets describe gs://${name} --project=${proj}")
            fi
        done < <(gcloud storage buckets list --project="$proj" --format="value(name,location,default_storage_class)" 2>/dev/null || true)
    fi

    # 7. Memorystore (Redis)
    if is_enabled "redis.googleapis.com"; then
        log_step "[$proj] Checando Memorystore Redis..."
        while IFS=$'\t' read -r name reg tier; do
            if [[ -n "$name" ]]; then
                log_found "$proj" "Memorystore" "Redis: ${name} [${tier}]" "$reg"
                DISCOVERED_RESOURCES+=("${proj}|${proj_name}|Memorystore|Redis Instance (${tier})|${name}|${reg}|gcloud redis instances delete ${name} --region=${reg} --project=${proj} --quiet|gcloud redis instances describe ${name} --region=${reg} --project=${proj}")
            fi
        done < <(gcloud redis instances list --project="$proj" --format="value(name.basename(),name.segment(3),tier)" 2>/dev/null || true)
    fi

    # 8. BigQuery Datasets
    if is_enabled "bigquery.googleapis.com"; then
        log_step "[$proj] Checando BigQuery..."
        if command -v bq &>/dev/null; then
            for ds in $(bq ls --project_id="$proj" --format=sparse 2>/dev/null | tail -n +3 | awk '{print $1}'); do
                if [[ -n "$ds" ]]; then
                    log_found "$proj" "BigQuery" "Dataset: ${ds}" "default"
                    DISCOVERED_RESOURCES+=("${proj}|${proj_name}|BigQuery|Dataset|${ds}|default|bq --project_id=${proj} rm -r -f -d ${ds}|bq --project_id=${proj} show ${ds}")
                fi
            done
        fi
    fi

    # 9. Artifact Registry
    if is_enabled "artifactregistry.googleapis.com"; then
        log_step "[$proj] Checando Artifact Registry..."
        while IFS=$'\t' read -r name loc format; do
            if [[ -n "$name" ]]; then
                log_found "$proj" "Artifact Registry" "Repositório: ${name} [${format}]" "$loc"
                DISCOVERED_RESOURCES+=("${proj}|${proj_name}|Artifact Registry|Repository (${format})|${name}|${loc}|gcloud artifacts repositories delete ${name} --location=${loc} --project=${proj} --quiet|gcloud artifacts repositories describe ${name} --location=${loc} --project=${proj}")
            fi
        done < <(gcloud artifacts repositories list --project="$proj" --format="value(name.basename(),name.segment(3),format)" 2>/dev/null || true)
    fi

    # 10. Pub/Sub Subscriptions & Topics
    if is_enabled "pubsub.googleapis.com"; then
        log_step "[$proj] Checando Pub/Sub..."
        while IFS=$'\t' read -r name; do
            if [[ -n "$name" ]]; then
                log_found "$proj" "Pub/Sub" "Subscription: ${name}" "global"
                DISCOVERED_RESOURCES+=("${proj}|${proj_name}|Pub/Sub|Subscription|${name}|global|gcloud pubsub subscriptions delete ${name} --project=${proj} --quiet|gcloud pubsub subscriptions describe ${name} --project=${proj}")
            fi
        done < <(gcloud pubsub subscriptions list --project="$proj" --format="value(name.basename())" 2>/dev/null || true)

        while IFS=$'\t' read -r name; do
            if [[ -n "$name" && "$name" != container-analysis-* ]]; then
                log_found "$proj" "Pub/Sub" "Topic: ${name}" "global"
                DISCOVERED_RESOURCES+=("${proj}|${proj_name}|Pub/Sub|Topic|${name}|global|gcloud pubsub topics delete ${name} --project=${proj} --quiet|gcloud pubsub topics describe ${name} --project=${proj}")
            fi
        done < <(gcloud pubsub topics list --project="$proj" --format="value(name.basename())" 2>/dev/null || true)
    fi

    # 11. Dataproc
    if is_enabled "dataproc.googleapis.com"; then
        log_step "[$proj] Checando Dataproc..."
        while IFS=$'\t' read -r name reg status; do
            if [[ -n "$name" ]]; then
                log_found "$proj" "Dataproc" "Cluster: ${name} [${status}]" "$reg"
                DISCOVERED_RESOURCES+=("${proj}|${proj_name}|Dataproc|Cluster (${status})|${name}|${reg}|gcloud dataproc clusters delete ${name} --region=${reg} --project=${proj} --quiet|gcloud dataproc clusters describe ${name} --region=${reg} --project=${proj}")
            fi
        done < <(gcloud dataproc clusters list --project="$proj" --format="value(clusterName,region,status.state)" 2>/dev/null || true)
    fi

    # 12. Vertex AI Workbenches
    if is_enabled "notebooks.googleapis.com"; then
        log_step "[$proj] Checando Vertex AI Workbenches..."
        while IFS=$'\t' read -r name loc; do
            if [[ -n "$name" ]]; then
                log_found "$proj" "Vertex AI" "Workbench: ${name}" "$loc"
                DISCOVERED_RESOURCES+=("${proj}|${proj_name}|Vertex AI|Workbench Instance|${name}|${loc}|gcloud workbench instances delete ${name} --location=${loc} --project=${proj} --quiet|gcloud workbench instances describe ${name} --location=${loc} --project=${proj}")
            fi
        done < <(gcloud workbench instances list --project="$proj" --format="value(name.basename(),location)" 2>/dev/null || true)
    fi

    local final_count=${#DISCOVERED_RESOURCES[@]}
    local diff=$((final_count - initial_count))
    if [[ $diff -eq 0 ]]; then
        log_success "Nenhum recurso tarifável encontrado no projeto '${proj}'."
    else
        log_warn "Total de ${diff} recurso(s) tarifável(is) encontrado(s) no projeto '${proj}'."
    fi
}

# ------------------------------------------------------------------------------
# Exibição do Relatório de Pré-Flight
# ------------------------------------------------------------------------------
display_preflight_report() {
    log_header "RELATÓRIO PRE-FLIGHT: CONSOLIDAÇÃO DE RECURSOS ENCONTRADOS"

    echo -e "${BOLD}Conta GCP Autenticada:${RESET} ${GREEN}${ACTIVE_ACCOUNT}${RESET}"
    if [[ "$ALL_PROJECTS" == true ]]; then
        echo -e "${BOLD}Escopo de Varredura:${RESET}    ${YELLOW}TODOS os projetos da conta (${#PROJECTS_FOUND[@]} projetos)${RESET}"
    else
        echo -e "${BOLD}Escopo de Varredura:${RESET}    Projeto ${CYAN}${TARGET_PROJECT}${RESET}"
    fi
    echo ""

    local total=${#DISCOVERED_RESOURCES[@]}
    if [[ $total -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✔ Nenhum recurso tarifável foi detectado no escopo selecionado!${RESET}"
        echo -e "${DIM}Todos os projetos auditados estão limpos de cobranças ativas para os serviços cobertos.${RESET}\n"
        exit 0
    fi

    echo -e "${YELLOW}${BOLD}Foram identificados ${total} recurso(s) tarifável(is) em todos os projetos varridos:${RESET}\n"

    printf "${BOLD}%-26s | %-20s | %-30s | %-32s | %-16s${RESET}\n" "PROJETO" "SERVIÇO" "TIPO" "NOME DO RECURSO" "LOCALIZAÇÃO"
    echo "-----------------------------------------------------------------------------------------------------------------------------------------"

    for item in "${DISCOVERED_RESOURCES[@]}"; do
        IFS='|' read -r proj pname srv rtype name loc del_cmd check_cmd <<< "$item"
        printf "%-26s | %-20s | %-30s | %-32s | %-16s\n" \
            "${proj:0:26}" "${srv:0:20}" "${rtype:0:30}" "${name:0:32}" "${loc:0:16}"
    done
    echo ""
}

# ------------------------------------------------------------------------------
# Confirmação do Usuário
# ------------------------------------------------------------------------------
request_confirmation() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${CYAN}${BOLD}[MODO DRY-RUN / SIMULAÇÃO ATIVO]${RESET}"
        echo -e "Nenhum comando de remoção foi executado. O pré-flight foi finalizado com sucesso.\n"
        exit 0
    fi

    if [[ "$AUTO_CONFIRM" == true ]]; then
        log_warn "Confirmação automática ativada via parâmetro (--yes / --force)."
        return 0
    fi

    echo -e "${RED}${BOLD}========================================================================================================${RESET}"
    echo -e "${RED}${BOLD}  ATENÇÃO: A REMOÇÃO DESTES RECURSOS É IRREVERSÍVEL! TODOS OS DADOS SERÃO PERDIDOS!                     ${RESET}"
    echo -e "${RED}${BOLD}========================================================================================================${RESET}"
    echo -e "Você está prestes a excluir ${BOLD}${#DISCOVERED_RESOURCES[@]}${RESET} recurso(s) nos projetos listados acima."
    echo ""
    read -r -p "Digite 'CONFIRMAR' ou 'SIM' para prosseguir com a exclusão de todos os recursos: " USER_INPUT

    case "$USER_INPUT" in
        "CONFIRMAR"|"confirmar"|"SIM"|"sim"|"yes"|"YES")
            log_info "Confirmação recebida. Iniciando processo de remoção..."
            ;;
        *)
            log_warn "Operação cancelada pelo usuário. Nenhum recurso foi alterado."
            exit 0
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Execução e Validação de Remoção
# ------------------------------------------------------------------------------
execute_and_verify_removal() {
    log_header "EXECUÇÃO DA REMOÇÃO E CONFIRMAÇÃO DE DELEÇÃO"

    local idx=1
    local total=${#DISCOVERED_RESOURCES[@]}

    for item in "${DISCOVERED_RESOURCES[@]}"; do
        IFS='|' read -r proj pname srv rtype name loc del_cmd check_cmd <<< "$item"

        echo -e "\n${BOLD}[$idx/$total] Removendo [Proj: ${CYAN}${proj}${RESET}] ${MAGENTA}${srv}${RESET} ➔ ${BOLD}${name}${RESET} (${CYAN}${loc}${RESET})...${RESET}"
        if [[ "$VERBOSE" == true ]]; then
            echo -e "${DIM}Comando: ${del_cmd}${RESET}"
        fi

        # Executa o comando de deleção
        local del_output
        local del_status=0
        del_output=$(eval "$del_cmd" 2>&1) || del_status=$?

        if [[ $del_status -ne 0 ]]; then
            log_error "Falha ao disparar comando de deleção para '${name}' no projeto '${proj}'"
            [[ "$VERBOSE" == true ]] && echo "$del_output"
            FAILED_DELETED+=("${proj}|${srv}|${name}|Falha no comando de deleção: ${del_output}")
            ((idx++))
            continue
        fi

        # Aguarda e verifica se o recurso foi realmente excluído do GCP
        echo -ne "${CYAN}  ⏳ Aguardando confirmação da remoção em '${proj}'...${RESET}"
        local max_retries=20
        local retry_count=0
        local is_deleted=false

        while [[ $retry_count -lt $max_retries ]]; do
            if ! eval "$check_cmd" &>/dev/null; then
                is_deleted=true
                break
            fi
            sleep 4
            echo -ne "."
            ((retry_count++))
        done
        echo ""

        if [[ "$is_deleted" == true ]]; then
            log_success "Confirmado: Recurso '${name}' foi completamente removido do projeto '${proj}'!"
            SUCCESS_DELETED+=("${proj}|${srv}|${rtype}|${name}|${loc}")
        else
            log_warn "A deleção de '${name}' foi iniciada, mas a confirmação de exclusão excedeu o timeout no projeto '${proj}'."
            FAILED_DELETED+=("${proj}|${srv}|${name}|Tempo limite excedido aguardando término da deleção")
        fi

        ((idx++))
    done
}

# ------------------------------------------------------------------------------
# Relatório Final de Pós-Execução
# ------------------------------------------------------------------------------
display_postflight_report() {
    log_header "RELATÓRIO FINAL DE PÓS-EXECUÇÃO"

    echo -e "${BOLD}Resumo Consolidado da Operação:${RESET}"
    echo -e "  • Total de recursos identificados:  ${BOLD}${#DISCOVERED_RESOURCES[@]}${RESET}"
    echo -e "  • Recursos removidos com sucesso:   ${GREEN}${BOLD}${#SUCCESS_DELETED[@]}${RESET}"
    echo -e "  • Recursos com falha / pendentes:   ${RED}${BOLD}${#FAILED_DELETED[@]}${RESET}"
    echo ""

    if [[ ${#SUCCESS_DELETED[@]} -gt 0 ]]; then
        echo -e "${GREEN}${BOLD}RECURSOS REMOVIDOS COM SUCESSO:${RESET}"
        printf "${BOLD}%-26s | %-20s | %-32s | %-16s${RESET}\n" "PROJETO" "SERVIÇO" "NOME DO RECURSO" "LOCALIZAÇÃO"
        echo "---------------------------------------------------------------------------------------------------------"
        for item in "${SUCCESS_DELETED[@]}"; do
            IFS='|' read -r proj srv rtype name loc <<< "$item"
            printf "%-26s | %-20s | %-32s | %-16s\n" "${proj:0:26}" "${srv:0:20}" "${name:0:32}" "${loc:0:16}"
        done
        echo ""
    fi

    if [[ ${#FAILED_DELETED[@]} -gt 0 ]]; then
        echo -e "${RED}${BOLD}RECURSOS COM FALHA OU PENDENTES DE CONFIRMAÇÃO:${RESET}"
        for item in "${FAILED_DELETED[@]}"; do
            IFS='|' read -r proj srv name reason <<< "$item"
            echo -e "${RED}✖${RESET} [${proj}] ${srv}: ${name} - ${DIM}${reason}${RESET}"
        done
        echo ""
    fi

    if [[ ${#FAILED_DELETED[@]} -eq 0 && ${#SUCCESS_DELETED[@]} -gt 0 ]]; then
        echo -e "${GREEN}${BOLD}✔ Todos os recursos tarifáveis identificados em todos os projetos foram removidos com sucesso!${RESET}\n"
    fi
}

# ------------------------------------------------------------------------------
# Fluxo Principal
# ------------------------------------------------------------------------------
main() {
    check_dependencies
    verify_gcloud_auth
    discover_projects

    log_header "VARREDURA DE RECURSOS TARIFÁVEIS GCP"

    if [[ "$ALL_PROJECTS" == true ]]; then
        for p_info in "${PROJECTS_FOUND[@]}"; do
            IFS='|' read -r pid pname <<< "$p_info"
            scan_project_resources "$pid" "$pname"
        done
    else
        local target_name="$TARGET_PROJECT"
        for p_info in "${PROJECTS_FOUND[@]}"; do
            if [[ "${p_info%%|*}" == "$TARGET_PROJECT" ]]; then
                target_name="${p_info#*|}"
                break
            fi
        done
        scan_project_resources "$TARGET_PROJECT" "$target_name"
    fi

    display_preflight_report
    request_confirmation
    execute_and_verify_removal
    display_postflight_report
}

main "$@"
