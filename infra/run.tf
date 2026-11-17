# Cloud Run. Terraform owns each service's configuration (identity, scaling, env, secrets, Cloud SQL link);
# the CI pipelines own the container image, so a release never shows up as drift here.

resource "google_cloud_run_v2_service" "app" {
  name     = "gatherinsight"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account                  = google_service_account.run.email
    max_instance_request_concurrency = 40
    timeout                          = "300s"

    scaling {
      min_instance_count = 0 # scale to zero between demos
      max_instance_count = 4
    }

    containers {
      image = "${local.registry_host}/${var.project_id}/gi/app:20261106-090055" # replaced by every release

      ports {
        name           = "http1"
        container_port = 8080
      }

      resources {
        cpu_idle          = true
        startup_cpu_boost = true
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
      }

      startup_probe {
        failure_threshold     = 1
        initial_delay_seconds = 0
        period_seconds        = 240
        timeout_seconds       = 240
        tcp_socket {
          port = 8080
        }
      }

      dynamic "env" {
        for_each = {
          AUTH_URL                = var.app_url
          CALL_TURN_URLS          = "turn:${google_compute_address.turn.address}:3478"
          DISABLE_IN_PROCESS_JOBS = "1" # Cloud Scheduler drives background work (see scheduler.tf)
          FILE_STORE              = "gcs"
          GCS_BUCKET              = google_storage_bucket.files.name
          UPLOAD_MAX_MB           = "30"
          VOICE_TRANSCRIBE        = "openrouter"
        }
        content {
          name  = env.key
          value = env.value
        }
      }

      # Secrets are mounted from Secret Manager; their values never pass through Terraform.
      dynamic "env" {
        for_each = {
          AUTH_SECRET        = "gi-auth-secret"
          CALL_TURN_SECRET   = "gi-call-turn-secret"
          DATABASE_URL       = "gi-database-url"
          JOBS_SECRET        = "gi-jobs-secret"
          MOBILE_JWT_SECRET  = "gi-mobile-jwt-secret"
          OPENROUTER_API_KEY = "gi-openrouter-api-key"
        }
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.this[env.value].secret_id
              version = "latest"
            }
          }
        }
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [local.sql_connection]
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      client,
      client_version,
      template[0].containers[0].image, # set by the app pipeline (private repository)
      traffic,                         # the pipeline tests each new revision with no traffic, then promotes it
    ]
  }
}

# Applies database migrations; the app pipeline points it at the new migrator image and runs it before rolling out.
resource "google_cloud_run_v2_job" "migrate" {
  name     = "gi-migrate"
  location = var.region

  template {
    task_count = 1

    template {
      service_account       = google_service_account.run.email
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
      max_retries           = 0
      timeout               = "600s"

      containers {
        image   = "${local.registry_host}/${var.project_id}/gi/migrator:20261106-090055" # replaced by every release
        command = ["npx"]
        args    = ["prisma", "migrate", "deploy"]

        env {
          name = "DATABASE_URL"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.this["gi-database-url"].secret_id
              version = "latest"
            }
          }
        }

        resources {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }

        volume_mounts {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }
      }

      volumes {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [local.sql_connection]
        }
      }
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      client,
      client_version,
      template[0].template[0].containers[0].image,
    ]
  }
}

resource "google_cloud_run_v2_service" "landing" {
  name     = "gatherinsight-landing"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    # Its own identity with no roles at all: a static site needs nothing from the project.
    service_account                  = google_service_account.landing.email
    max_instance_request_concurrency = 80
    timeout                          = "300s"

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }

    containers {
      image = "${local.registry_host}/${var.project_id}/cloud-run-source-deploy/gatherinsight-landing@sha256:abc40b3a8b21381502a7d5be87af0dfc6200a71a0e368c0d4c3d564f4d0fc178"

      ports {
        name           = "http1"
        container_port = 8080
      }

      resources {
        cpu_idle          = true
        startup_cpu_boost = true
        limits = {
          cpu    = "1"
          memory = "256Mi"
        }
      }

      startup_probe {
        failure_threshold     = 1
        initial_delay_seconds = 0
        period_seconds        = 240
        timeout_seconds       = 240
        tcp_socket {
          port = 8080
        }
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      client,
      client_version,
      build_config,                    # left over from the first source-based deploy
      template[0].containers[0].image, # set by .github/workflows/landing.yml
    ]
  }
}

# Both sites are public.
resource "google_cloud_run_v2_service_iam_member" "app_public" {
  name     = google_cloud_run_v2_service.app.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "landing_public" {
  name     = google_cloud_run_v2_service.landing.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Custom domains (DNS records are kept at the domain registrar).
resource "google_cloud_run_domain_mapping" "app" {
  name     = var.app_domain
  location = var.region

  metadata {
    namespace = var.project_id
  }

  spec {
    route_name       = google_cloud_run_v2_service.app.name
    certificate_mode = "AUTOMATIC"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_cloud_run_domain_mapping" "landing" {
  name     = var.landing_domain
  location = var.region

  metadata {
    namespace = var.project_id
  }

  spec {
    route_name       = google_cloud_run_v2_service.landing.name
    certificate_mode = "AUTOMATIC"
  }

  lifecycle {
    prevent_destroy = true
  }
}
