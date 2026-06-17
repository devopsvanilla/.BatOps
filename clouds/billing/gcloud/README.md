# GCP Billing Export para BigQuery

Este diretório provisiona o dataset BigQuery e a exportação de faturamento por hora.

## Requisitos

- Terraform >= 1.5.0
- Provider `hashicorp/google`
- Permissões:
  - `roles/billing.admin` na Billing Account
  - `roles/bigquery.admin` ou `roles/bigquery.dataEditor` no projeto destino

## Uso

1. Navegue até o diretório:
   ```bash
   cd /home/devopsvanilla/.batops/clouds/billing/gcloud
   ```

2. Crie um arquivo `terraform.tfvars` a partir do exemplo:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Atualize `terraform.tfvars` com seus valores reais. Se preferir usar o arquivo de credenciais da service account, informe a variável `credentials_file`:
   ```hcl
   credentials_file = "../../credentials/gcloud/gcloud-sa.json.json"
   ```

4. Inicialize o Terraform:
   ```bash
   terraform init
   ```

5. Valide a configuração:
   ```bash
   terraform validate
   ```

6. Planeje e aplique:
   ```bash
   terraform plan -var-file=terraform.tfvars
   terraform apply -var-file=terraform.tfvars
   ```

### Se você estiver autenticando com service account JSON

Se o provider não encontrar credenciais ADC, informe o arquivo de credenciais JSON no `terraform.tfvars` ou faça login ADC:

```bash
gcloud auth application-default login
```

ou, usando o JSON diretamente no `terraform.tfvars`:

```hcl
credentials_file = "../../credentials/gcloud/gcloud-sa.json.json"
```

## Verificação após aplicação

Após a aplicação, você pode verificar se os recursos foram criados corretamente:

```bash
terraform show -json | jq '.values.root_module.resources[] | {type: .type, name: .name, values: .values}'
```

ou para ver apenas os outputs:

```bash
terraform output
```

No GCP, confirme manualmente:

```bash
bq --project_id=${PROJECT_ID} show --format=prettyjson ${DATASET_ID}
```

E verifique se a exportação de billing está ativa:

```bash
gcloud beta billing accounts data-exports list --billing-account="${BILLING_ACCOUNT_ID}"
```

Substitua `${PROJECT_ID}`, `${DATASET_ID}` e `${BILLING_ACCOUNT_ID}` pelos valores reais.

## Ativação final da exportação no Console do GCP

A ativação da exportação de Billing para BigQuery precisa ser feita manualmente no Console do GCP, pois a API pública do Cloud Billing não expõe um recurso Terraform para isso.

1. Acesse o Console do GCP.
2. Vá para `Faturamento` > `Exportação do Faturamento`.
3. Selecione na página 'Custo de uso detalhado'.
4. Clique em `Ativar exportação detalhada`.
5. Escolha o projeto e o dataset criados pelo Terraform:
   - Projeto: `<SEU PROJETO>`
   - Dataset: `billing_export`
6. Salve as configurações.

Como o Terraform já aplicou a permissão `roles/bigquery.dataEditor` para a conta de serviço `billing-export-bigquery@system.gserviceaccount.com`, o Console deverá aceitar a configuração sem erros de autorização.

## Reverter a implantação

Para destruir os recursos provisionados pelo Terraform:

```bash
terraform destroy -var-file=terraform.tfvars
```

Se quiser uma reversão parcial, use `terraform plan -destroy -var-file=terraform.tfvars` antes para revisar o que será removido.
## Observações

- O backend usado aqui é `local` para manter o setup simples.
- Em produção, migre para um backend remoto como GCS e proteja o estado.
- O `depends_on` garante que o dataset seja criado antes do billing export.
