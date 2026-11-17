# Secret Manager: Terraform manages that the secrets exist and who may read them. The values are added
# out of band (`gcloud secrets versions add`) and never appear in this repository.

locals {
  secrets = toset([
    "gi-auth-secret",        # signs sessions, encrypts stored integration keys
    "gi-call-turn-secret",   # shared with the TURN relay for short-lived call credentials
    "gi-database-url",       # PostgreSQL connection string (Cloud SQL socket)
    "gi-jobs-secret",        # bearer token Cloud Scheduler sends to /api/internal/jobs/*
    "gi-mobile-jwt-secret",  # signs the surveyor phone app's tokens
    "gi-openrouter-api-key", # speech-to-text and AI summaries
  ])
}

resource "google_secret_manager_secret" "this" {
  for_each  = local.secrets
  secret_id = each.value

  replication {
    auto {}
  }

  lifecycle {
    prevent_destroy = true
  }
}

# The relay VM may read exactly one secret.
resource "google_secret_manager_secret_iam_member" "turn_reads_turn_secret" {
  secret_id = google_secret_manager_secret.this["gi-call-turn-secret"].id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.turn.member
}

resource "google_secret_manager_secret_iam_member" "app_reads_turn_secret" {
  secret_id = google_secret_manager_secret.this["gi-call-turn-secret"].id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.run.member
}

resource "google_secret_manager_secret_iam_member" "app_reads_openrouter_key" {
  secret_id = google_secret_manager_secret.this["gi-openrouter-api-key"].id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.run.member
}
