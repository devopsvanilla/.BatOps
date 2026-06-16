output "dataset_id" {
  description = "ID do dataset BigQuery criado para exportação de billing."
  value       = google_bigquery_dataset.billing_dataset.dataset_id
}

output "dataset_self_link" {
  description = "Link completo do dataset BigQuery criado."
  value       = google_bigquery_dataset.billing_dataset.self_link
}
