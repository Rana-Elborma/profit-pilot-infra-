output "gcp_project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "gcp_region" {
  description = "GCP region used for all resources"
  value       = var.region
}

output "artifact_registry_url" {
  description = "Artifact Registry base URL — append /<image>:<tag> when pushing"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/profit-pilot"
}

output "core_api_url" {
  description = "Public HTTPS URL for the core-api Cloud Run service"
  value       = google_cloud_run_v2_service.core_api.uri
}

output "analytics_api_url" {
  description = "Public HTTPS URL for the analytics-api Cloud Run service"
  value       = google_cloud_run_v2_service.analytics_api.uri
}

output "wif_provider" {
  description = "Workload Identity Provider — goes into the WIF_PROVIDER GitHub Secret"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "service_account_email" {
  description = "CI/CD service account email — goes into the WIF_SERVICE_ACCOUNT GitHub Secret"
  value       = google_service_account.profit_pilot_sa.email
}
