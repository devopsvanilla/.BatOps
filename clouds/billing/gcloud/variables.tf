variable "project_id" {
  type        = string
  description = "ID do projeto GCP onde o dataset BigQuery será criado."
}

variable "billing_account_id" {
  type        = string
  description = "ID da conta de faturamento GCP (por exemplo, 017300-1AD74D-000DB9)."
}

variable "dataset_id" {
  type        = string
  description = "ID do dataset BigQuery para os exports de billing."
  default     = "billing_export"
}

variable "location" {
  type        = string
  description = "Localização do dataset BigQuery."
  default     = "US"
}

variable "export_type" {
  type        = string
  description = "Tipo de exportação de billing."
  default     = "DETAILED_COST"
}

variable "credentials_file" {
  type        = string
  description = "Caminho para o arquivo JSON da service account, opcional. Deixe vazio para usar Application Default Credentials."
  default     = ""
}
