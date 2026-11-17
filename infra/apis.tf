locals {
  services = toset([
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com", # project IAM from CI (Workload Identity callers bill to this project)
    "cloudscheduler.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ])
}

resource "google_project_service" "this" {
  for_each = local.services

  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}
