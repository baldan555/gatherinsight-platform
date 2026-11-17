#!/usr/bin/env bash
# Confirms that the deployer identity may do every release step, without changing anything. Runs on every
# push to main, even while the database is off, so a missing permission shows up before it matters.
# Needs PROJECT_ID, REGION, SERVICE, MIGRATE_JOB and an authenticated gcloud.
set -euo pipefail
: "${PROJECT_ID:?}" "${REGION:?}" "${SERVICE:?}" "${MIGRATE_JOB:?}"

token="$(gcloud auth print-access-token)"
fail=0

check() { # label, resource URL, permissions...
  local label="$1" url="$2"; shift 2
  local body granted missing=()
  body="$(jq -nc '{permissions: $ARGS.positional}' --args "$@")"
  granted="$(curl -fsS -X POST -H "Authorization: Bearer ${token}" -H "Content-Type: application/json" \
    -d "$body" "${url}:testIamPermissions" | jq -r '.permissions // [] | .[]')"
  for p in "$@"; do grep -qx "$p" <<<"$granted" || missing+=("$p"); done
  if [ ${#missing[@]} -eq 0 ]; then
    printf '  ok       %s\n' "$label"
  else
    printf '  MISSING  %s: %s\n' "$label" "${missing[*]}"
    fail=1
  fi
}

run="https://run.googleapis.com/v2/projects/${PROJECT_ID}/locations/${REGION}"
check "push images to Artifact Registry" \
  "https://artifactregistry.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/repositories/gi" \
  artifactregistry.repositories.uploadArtifacts
check "point the migration job at a new image and run it" "${run}/jobs/${MIGRATE_JOB}" \
  run.jobs.get run.jobs.update run.jobs.run
check "deploy a revision and move traffic" "${run}/services/${SERVICE}" \
  run.services.get run.services.update
check "start revisions as the runtime identity" \
  "https://iam.googleapis.com/v1/projects/${PROJECT_ID}/serviceAccounts/gi-run@${PROJECT_ID}.iam.gserviceaccount.com" \
  iam.serviceAccounts.actAs
check "follow migration runs and read the database state" \
  "https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT_ID}" \
  run.executions.get cloudsql.instances.get

exit "$fail"
