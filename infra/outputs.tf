output "workload_identity_provider" {
  description = "Value for google-github-actions/auth `workload_identity_provider`."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "ci_service_accounts" {
  description = "Service account each pipeline impersonates."
  value       = { for k, sa in google_service_account.ci : k => sa.email }
}

output "app_url" {
  description = "Public address of the web application."
  value       = "https://${var.app_domain}"
}

output "landing_url" {
  description = "Public address of the landing page."
  value       = "https://${var.landing_domain}"
}

output "landing_image_repository" {
  description = "Where the landing pipeline pushes its images."
  value       = "${local.registry_host}/${var.project_id}/${google_artifact_registry_repository.landing.repository_id}"
}
