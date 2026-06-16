resource "google_bigquery_dataset" "billing_dataset" {
  dataset_id = var.dataset_id
  project    = var.project_id
  location   = var.location

  description = "Dataset utilizado para exportação de custo detalhado do billing."
  labels = {
    managed_by = "terraform"
    purpose    = "gcp_billing_export"
  }
}

resource "google_bigquery_dataset_iam_member" "billing_writer" {
  dataset_id = google_bigquery_dataset.billing_dataset.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:billing-export-bigquery@system.gserviceaccount.com"
}
