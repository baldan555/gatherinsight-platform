# GatherInsight on Google Cloud
#
#   Cloud Run  gatherinsight          Next.js app + API (surveyor phone app, public survey links)
#   Cloud Run  gatherinsight-landing  static landing page (nginx)
#   Cloud Run  job gi-migrate         `prisma migrate deploy`, run by the app pipeline before each release
#   Cloud SQL  gi-db                  PostgreSQL 16 (switched off between demos: see scripts/power.sh)
#   Storage    gatherinsight-gi-files survey photos, voice answers, exports (private, signed access only)
#   Scheduler  4 jobs                 background work (field alerts, exports, deadlines, voice transcription)
#   Compute    gi-turn                TURN relay for recorded phone interviews (WebRTC)
#
# Everything here already existed before Terraform: imports.tf adopts it without recreating anything.

locals {
  run_parent     = "projects/${var.project_id}/locations/${var.region}"
  sql_connection = "${var.project_id}:${var.region}:${google_sql_database_instance.main.name}"
  registry_host  = "${var.region}-docker.pkg.dev"
}
