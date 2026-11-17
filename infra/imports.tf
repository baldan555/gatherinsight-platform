# The platform was running before it was described in Terraform. These blocks adopted each existing
# resource into state on the first apply (no downtime, nothing recreated). Once a resource is in state
# its import block is a no-op; they stay here as the record of what was adopted.

locals {
  imported_services = setsubtract(local.services, ["cloudresourcemanager.googleapis.com"]) # newly enabled
}

import {
  for_each = local.imported_services
  to       = google_project_service.this[each.value]
  id       = "${var.project_id}/${each.value}"
}

# Cloud Run
import {
  to = google_cloud_run_v2_service.app
  id = "${local.run_parent}/services/gatherinsight"
}
import {
  to = google_cloud_run_v2_service.landing
  id = "${local.run_parent}/services/gatherinsight-landing"
}
import {
  to = google_cloud_run_v2_job.migrate
  id = "${local.run_parent}/jobs/gi-migrate"
}
import {
  to = google_cloud_run_v2_service_iam_member.app_public
  id = "${local.run_parent}/services/gatherinsight roles/run.invoker allUsers"
}
import {
  to = google_cloud_run_v2_service_iam_member.landing_public
  id = "${local.run_parent}/services/gatherinsight-landing roles/run.invoker allUsers"
}
import {
  to = google_cloud_run_domain_mapping.app
  id = "locations/${var.region}/namespaces/${var.project_id}/domainmappings/${var.app_domain}"
}
import {
  to = google_cloud_run_domain_mapping.landing
  id = "locations/${var.region}/namespaces/${var.project_id}/domainmappings/${var.landing_domain}"
}

# Data
import {
  to = google_sql_database_instance.main
  id = "projects/${var.project_id}/instances/gi-db"
}
import {
  to = google_storage_bucket.files
  id = "${var.project_id}-gi-files"
}
import {
  to = google_storage_bucket_iam_member.files_app
  id = "b/${var.project_id}-gi-files roles/storage.objectAdmin serviceAccount:gi-run@${var.project_id}.iam.gserviceaccount.com"
}
import {
  to = google_storage_bucket.tfstate
  id = "${var.project_id}-tfstate"
}
import {
  to = google_artifact_registry_repository.gi
  id = "${local.run_parent}/repositories/gi"
}

# Secrets (metadata and access only)
import {
  for_each = local.secrets
  to       = google_secret_manager_secret.this[each.value]
  id       = "projects/${var.project_id}/secrets/${each.value}"
}
import {
  to = google_secret_manager_secret_iam_member.turn_reads_turn_secret
  id = "projects/${var.project_id}/secrets/gi-call-turn-secret roles/secretmanager.secretAccessor serviceAccount:gi-turn@${var.project_id}.iam.gserviceaccount.com"
}
import {
  to = google_secret_manager_secret_iam_member.app_reads_turn_secret
  id = "projects/${var.project_id}/secrets/gi-call-turn-secret roles/secretmanager.secretAccessor serviceAccount:gi-run@${var.project_id}.iam.gserviceaccount.com"
}
import {
  to = google_secret_manager_secret_iam_member.app_reads_openrouter_key
  id = "projects/${var.project_id}/secrets/gi-openrouter-api-key roles/secretmanager.secretAccessor serviceAccount:gi-run@${var.project_id}.iam.gserviceaccount.com"
}

# Background jobs
import {
  for_each = local.scheduler_jobs
  to       = google_cloud_scheduler_job.jobs[each.key]
  id       = "${local.run_parent}/jobs/${each.key}"
}

# Identities
import {
  to = google_service_account.run
  id = "projects/${var.project_id}/serviceAccounts/gi-run@${var.project_id}.iam.gserviceaccount.com"
}
import {
  to = google_service_account.turn
  id = "projects/${var.project_id}/serviceAccounts/gi-turn@${var.project_id}.iam.gserviceaccount.com"
}
import {
  to = google_project_iam_member.run_sql_client
  id = "${var.project_id} roles/cloudsql.client serviceAccount:gi-run@${var.project_id}.iam.gserviceaccount.com"
}
import {
  to = google_project_iam_member.run_secret_accessor
  id = "${var.project_id} roles/secretmanager.secretAccessor serviceAccount:gi-run@${var.project_id}.iam.gserviceaccount.com"
}

# TURN relay
import {
  to = google_compute_address.turn
  id = "projects/${var.project_id}/regions/${var.region}/addresses/gi-turn-ip"
}
import {
  to = google_compute_instance.turn
  id = "projects/${var.project_id}/zones/${var.zone}/instances/gi-turn"
}
import {
  to = google_compute_firewall.turn_allow
  id = "projects/${var.project_id}/global/firewalls/gi-turn-allow"
}
import {
  to = google_compute_firewall.turn_iap
  id = "projects/${var.project_id}/global/firewalls/gi-turn-allow-iap"
}
import {
  to = google_compute_firewall.turn_deny
  id = "projects/${var.project_id}/global/firewalls/gi-turn-deny-admin"
}
