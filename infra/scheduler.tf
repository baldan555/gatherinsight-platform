# Background work runs on Cloud Scheduler instead of in-process timers, because Cloud Run scales to zero.
# The jobs are paused while the database is off; scripts/power.sh pauses and resumes them, so Terraform
# ignores that flag.

locals {
  scheduler_jobs = {
    "gi-job-field-alerts"      = { schedule = "*/5 * * * *", path = "field-alerts" }       # GPS / quota alerts for field teams
    "gi-job-scheduled-exports" = { schedule = "*/15 * * * *", path = "scheduled-exports" } # e-mailed result exports
    "gi-job-deadline-notices"  = { schedule = "0 * * * *", path = "deadline-notices" }     # survey deadline reminders
    "gi-job-voice-survey"      = { schedule = "*/2 * * * *", path = "voice-survey" }       # transcribe spoken answers
  }
}

# Read at plan time so the token is never written in code. Terraform marks it sensitive, so plans and
# CI logs show "(sensitive value)" instead.
data "google_secret_manager_secret_version" "jobs" {
  secret = google_secret_manager_secret.this["gi-jobs-secret"].secret_id
}

resource "google_cloud_scheduler_job" "jobs" {
  for_each = local.scheduler_jobs

  name             = each.key
  region           = var.region
  schedule         = each.value.schedule
  time_zone        = "Asia/Jakarta"
  attempt_deadline = "300s"

  http_target {
    http_method = "POST"
    uri         = "${var.app_url}/api/internal/jobs/${each.value.path}"
    headers = {
      Authorization = "Bearer ${data.google_secret_manager_secret_version.jobs.secret_data}"
    }
  }

  retry_config {
    retry_count          = 0
    max_retry_duration   = "0s"
    min_backoff_duration = "5s"
    max_backoff_duration = "3600s"
    max_doublings        = 5
  }

  lifecycle {
    ignore_changes = [paused]
  }
}
