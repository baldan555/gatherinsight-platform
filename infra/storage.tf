# Files people upload during fieldwork. Private: the app hands out short-lived access after checking the user.
resource "google_storage_bucket" "files" {
  name                        = "${var.project_id}-gi-files"
  location                    = "ASIA-SOUTHEAST1"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  soft_delete_policy {
    retention_duration_seconds = 604800 # 7 days to undo an accidental delete
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_storage_bucket_iam_member" "files_app" {
  bucket = google_storage_bucket.files.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.run.member
}

# Terraform state (versioned, so any earlier state can be restored).
resource "google_storage_bucket" "tfstate" {
  name                        = "${var.project_id}-tfstate"
  location                    = "ASIA-SOUTHEAST1"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  soft_delete_policy {
    retention_duration_seconds = 604800
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Container images of the app and the migrator.
resource "google_artifact_registry_repository" "gi" {
  repository_id = "gi"
  location      = var.region
  format        = "DOCKER"

  # Every release adds two images. Old ones would be removed by these rules; they run as a dry run
  # (logged, nothing deleted) until the results have been reviewed.
  cleanup_policy_dry_run = true

  cleanup_policies {
    id     = "keep-recent-releases"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }

  cleanup_policies {
    id     = "delete-older-than-30-days"
    action = "DELETE"
    condition {
      older_than = "2592000s"
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Container images of the landing page (its own repository, so its deployer cannot touch the app images).
resource "google_artifact_registry_repository" "landing" {
  repository_id = "landing"
  location      = var.region
  format        = "DOCKER"
  description   = "Landing page images, pushed by GitHub Actions"

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-last-5"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }

  cleanup_policies {
    id     = "delete-older-than-14-days"
    action = "DELETE"
    condition {
      older_than = "1209600s"
    }
  }
}
