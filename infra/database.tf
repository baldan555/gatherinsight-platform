# PostgreSQL for the app. It is switched off between demos (activation policy NEVER) by scripts/power.sh,
# so Terraform deliberately ignores the on/off state and never starts or stops it.
#
# Databases and users are not managed here: reading them needs a running instance, and user passwords
# belong in Secret Manager, not in Terraform state.

resource "google_sql_database_instance" "main" {
  name                = "gi-db"
  region              = var.region
  database_version    = "POSTGRES_16"
  deletion_protection = true

  settings {
    tier              = "db-f1-micro"
    edition           = "ENTERPRISE"
    availability_type = "ZONAL"
    pricing_plan      = "PER_USE"
    activation_policy = "NEVER"

    disk_type       = "PD_SSD"
    disk_size       = 20
    disk_autoresize = true

    deletion_protection_enabled = true
    enable_dataplex_integration = true

    backup_configuration {
      enabled                        = true
      start_time                     = "19:00" # 02:00 in Jakarta
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = 14
        retention_unit   = "COUNT"
      }
    }

    # Public IP without authorised networks: only the Cloud SQL connector (IAM-checked) can reach it.
    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
    }

    location_preference {
      zone = "asia-southeast1-c"
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      settings[0].activation_policy, # on/off is scripts/power.sh's job
    ]
  }
}
