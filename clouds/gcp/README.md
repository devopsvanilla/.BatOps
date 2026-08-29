# GCP Resource Management - Remove Billable Resources

Script para identificação e remoção segura de recursos tarifáveis (não gratuitos) em múltiplos projetos ou em projetos específicos da conta do Google Cloud Platform (GCP).

## 📋 Funcionalidades

1. **Descoberta Automática de Múltiplos Projetos**:
   - Detecta todos os projetos ativos associados à conta GCP conectada.
   - Permite varredura interativa, em todos os projetos (`--all-projects`) ou em um projeto específico (`-p <ID>`).

2. **Rastreamento em Tempo Real com Indicação de Origem**:
   - Exibe mensagens em tempo real indicando exatamente o **projeto**, **serviço**, **nome do recurso** e **localização/região** onde cada item tarifável foi encontrado.

3. **Pre-flight Discovery Consolidado**:
   - Identifica recursos com cobranças ativas (Compute Engine VMs, Discos persistentes, Snapshots, IPs Estáticos externos, Load Balancers / Forwarding Rules, Cloud NAT & Routers, VPNs, GKE Clusters, Cloud SQL, Cloud Run, Cloud Functions, GCS Buckets, BigQuery Datasets, Artifact Registry, Memorystore Redis, Dataproc e Vertex AI).
   - Apresenta um relatório tabular agrupado por projeto antes de qualquer ação.

4. **Confirmação Explícita de Segurança**:
   - Exige digitação de `CONFIRMAR` ou `SIM` antes de executar qualquer exclusão.
   - Suporte a modo `--dry-run` para apenas simular e auditar sem risco.

5. **Execução Ordenada e Validação Pós-Remoção**:
   - Executa a exclusão respeitando as dependências entre serviços de nuvem.
   - Realiza polling/checagem ativa até confirmar a exclusão de cada recurso do GCP.
   - Apresenta relatório final consolidando recursos removidos com sucesso e eventuais pendências por projeto.

---

## 🚀 Como Utilizar

Acesse o diretório no terminal:
```bash
cd ~/.batops/clouds/gcp
```

### 1. Varredura e Simulação em Todos os Projetos da Conta (Dry-Run)
```bash
./remove-billable-resources.sh --all-projects --dry-run
```

### 2. Executar em Todos os Projetos da Conta (com Confirmação)
```bash
./remove-billable-resources.sh --all-projects
```

### 3. Modo Interativo (Apresenta Menu de Escolha de Projetos)
```bash
./remove-billable-resources.sh
```

### 4. Executar em um Projeto Específico
```bash
./remove-billable-resources.sh -p meu-projeto-especifico
```

---

## ⚙ Opções e Argumentos

| Opção | Descrição |
| :--- | :--- |
| `-a, --all-projects` | Escaneia e remove recursos em **TODOS os projetos ativos** da conta |
| `-p, --project <ID>` | Define um projeto GCP específico para varredura |
| `-d, --dry-run` | Executa apenas a varredura (Pré-Flight) sem deletar nada |
| `-y, --yes, --force` | Auto-confirma a remoção (utilize com cautela) |
| `-v, --verbose` | Exibe comandos e logs detalhados |
| `-h, --help` | Exibe o menu de ajuda |
