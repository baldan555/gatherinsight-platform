# Identities. Every workload and every pipeline has its own service account with only what it needs,
# and GitHub Actions signs in with short-lived OIDC tokens (Workload Identity Federation): there is no
# service account key anywhere.

# ---------------------------------------------------------------- runtime identities

resource "google_service_account" "run" {
  account_id   = "gi-run"
  display_name = "GatherInsight runtime"
}

resource "google_project_iam_member" "run_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = google_service_account.run.member
}

resource "google_project_iam_member" "run_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = google_service_account.run.member
}

resource "google_service_account" "turn" {
  account_id   = "gi-turn"
  display_name = "TURN relay (reads its own secret only)"
}

resource "google_service_account" "landing" {
  account_id   = "gi-landing"
  display_name = "Landing page runtime (no permissions)"
  description  = "Runs the static landing page. Deliberately has no roles."
}

# ---------------------------------------------------------------- GitHub Actions federation

# (A pool named "github" in this project belongs to another site's pipeline and is left alone.)
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "gi-github"
  display_name              = "GatherInsight GitHub Actions"
  description               = "OIDC tokens from the GatherInsight repositories"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  # Roles are granted on numeric repository ids plus the branch or event, never on names or on the
  # `sub` claim, whose format GitHub lets each repository change.
  attribute_mapping = {
    "google.subject"         = "assertion.sub" # shown in audit logs
    "attribute.repository"   = "assertion.repository"
    "attribute.ref"          = "assertion.ref"
    "attribute.repo_ref"     = "assertion.repository_id + '/' + assertion.ref"        # e.g. 1460997570/refs/heads/main
    "attribute.repo_event"   = "assertion.repository_id + '/' + assertion.event_name" # e.g. 1460997570/pull_request
    "attribute.workflow_ref" = "assertion.workflow_ref"
  }

  # Tokens from any other account or repository are rejected before any role is even considered, and so
  # are pull_request_target runs (they carry main's ref but can be started by outside pull requests).
  attribute_condition = format(
    "assertion.repository_owner_id == '%s' && assertion.repository_id in [%s] && assertion.event_name != 'pull_request_target'",
    var.github_owner_id,
    join(", ", [for id in values(var.github_repo_ids) : "'${id}'"]),
  )

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

locals {
  wif_pool = "principalSet://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}"

  main_of = { for k, id in var.github_repo_ids : k => "${local.wif_pool}/attribute.repo_ref/${id}/refs/heads/main" }

  # Which GitHub workflow runs may act as which deployer. Only runs on main (pushes, manual runs, the
  # weekly drift check) can deploy or apply; pull requests get a read-only identity for `terraform plan`.
  ci_accounts = {
    gh-deploy-app = {
      display    = "GitHub: release the app"
      principals = [local.main_of.app]
    }
    gh-deploy-landing = {
      display    = "GitHub: deploy the landing page"
      principals = [local.main_of.platform]
    }
    gh-terraform = {
      display    = "GitHub: terraform apply"
      principals = [local.main_of.platform]
    }
    gh-terraform-plan = {
      display    = "GitHub: terraform plan (read-only)"
      principals = ["${local.wif_pool}/attribute.repo_event/${var.github_repo_ids.platform}/pull_request"]
    }
  }

  ci_bindings = merge([
    for sa, cfg in local.ci_accounts : {
      for i, p in cfg.principals : "${sa}#${i}" => { sa = sa, principal = p }
    }
  ]...)
}

resource "google_service_account" "ci" {
  for_each     = local.ci_accounts
  account_id   = each.key
  display_name = each.value.display
}

resource "google_service_account_iam_member" "ci_federation" {
  for_each           = local.ci_bindings
  service_account_id = google_service_account.ci[each.value.sa].name
  role               = "roles/iam.workloadIdentityUser"
  member             = each.value.principal
}

# ---------------------------------------------------------------- gh-deploy-app: build, migrate, roll out

resource "google_artifact_registry_repository_iam_member" "deploy_app_push" {
  repository = google_artifact_registry_repository.gi.name
  location   = var.region
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.ci["gh-deploy-app"].member
}

resource "google_cloud_run_v2_service_iam_member" "deploy_app_service" {
  name     = google_cloud_run_v2_service.app.name
  location = var.region
  role     = "roles/run.developer"
  member   = google_service_account.ci["gh-deploy-app"].member
}

resource "google_cloud_run_v2_job_iam_member" "deploy_app_migrate" {
  name     = google_cloud_run_v2_job.migrate.name
  location = var.region
  role     = "roles/run.developer"
  member   = google_service_account.ci["gh-deploy-app"].member
}

# New revisions and migration runs execute as gi-run, so the deployer must be allowed to hand them that identity.
resource "google_service_account_iam_member" "deploy_app_acts_as_runtime" {
  service_account_id = google_service_account.run.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.ci["gh-deploy-app"].member
}

# Read-only: lets the pipeline follow migration executions and see whether the database is switched on.
resource "google_project_iam_member" "deploy_app_readonly" {
  for_each = toset(["roles/run.viewer", "roles/cloudsql.viewer"])
  project  = var.project_id
  role     = each.value
  member   = google_service_account.ci["gh-deploy-app"].member
}

# ---------------------------------------------------------------- gh-deploy-landing

resource "google_artifact_registry_repository_iam_member" "deploy_landing_push" {
  repository = google_artifact_registry_repository.landing.name
  location   = var.region
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.ci["gh-deploy-landing"].member
}

resource "google_cloud_run_v2_service_iam_member" "deploy_landing_service" {
  name     = google_cloud_run_v2_service.landing.name
  location = var.region
  role     = "roles/run.developer"
  member   = google_service_account.ci["gh-deploy-landing"].member
}

resource "google_service_account_iam_member" "deploy_landing_acts_as_runtime" {
  service_account_id = google_service_account.landing.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.ci["gh-deploy-landing"].member
}

# ---------------------------------------------------------------- gh-terraform: apply this configuration
# Managing IAM is inherently powerful, so this identity is the one to guard: it can only be used by
# pushes to main of the platform repository, and the workflow refuses plans that delete anything.

resource "google_project_iam_member" "terraform_apply" {
  for_each = toset([
    "roles/artifactregistry.admin",
    "roles/cloudscheduler.admin",
    "roles/cloudsql.admin",
    "roles/compute.instanceAdmin.v1",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/run.admin",
    "roles/secretmanager.admin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/storage.admin",
  ])
  project = var.project_id
  role    = each.value
  member  = google_service_account.ci["gh-terraform"].member
}

# ---------------------------------------------------------------- gh-terraform-plan: read-only

resource "google_project_iam_member" "terraform_plan" {
  for_each = toset(["roles/viewer", "roles/iam.securityReviewer"])
  project  = var.project_id
  role     = each.value
  member   = google_service_account.ci["gh-terraform-plan"].member
}

resource "google_storage_bucket_iam_member" "terraform_plan_state" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.ci["gh-terraform-plan"].member
}

# The scheduler jobs carry this token, so a plan has to read it to compare.
resource "google_secret_manager_secret_iam_member" "terraform_plan_jobs_secret" {
  secret_id = google_secret_manager_secret.this["gi-jobs-secret"].id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.ci["gh-terraform-plan"].member
}
