#!/usr/bin/env bash
# Turns the online system off while nobody is testing, and back on (cost control for a demo environment):
#   bash scripts/power.sh status    what is running now (changes nothing)
#   bash scripts/power.sh off       pauses the four scheduled jobs, then stops Cloud SQL (the web and the phone apps stop working; no data is lost)
#   bash scripts/power.sh on        starts Cloud SQL, waits until it is ready, resumes the jobs, checks that the web answers
# While it is off you still pay for the database disk and its backups (about half of what Cloud SQL costs), not for its processor and memory.
# Cloud Run needs nothing: it already runs with min-instances 0, so it costs next to nothing while nobody calls it.
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-gatherinsight}"
REGION="${REGION:-asia-southeast1}"
SQL_INSTANCE="${SQL_INSTANCE:-gi-db}"
APP_URL="${APP_URL:-https://gatherinsight-pmrvdosmoq-as.a.run.app}"
JOBS=(gi-job-field-alerts gi-job-scheduled-exports gi-job-deadline-notices gi-job-voice-survey)

g() { gcloud --project "$PROJECT_ID" "$@"; }
sql_state() { g sql instances describe "$SQL_INSTANCE" --format="value(state)" 2>/dev/null; }
health() { curl -s -m 60 -o /dev/null -w '%{http_code}' "${APP_URL}/api/health" 2>/dev/null || echo "000"; }

status() {
  echo "Cloud SQL ($SQL_INSTANCE): $(sql_state)  [RUNNABLE = on, STOPPED = off]"
  for j in "${JOBS[@]}"; do echo "  scheduler $j: $(g scheduler jobs describe "$j" --location "$REGION" --format='value(state)' 2>/dev/null || echo '?')  [ENABLED = on, PAUSED = off]"; done
  echo "Web ${APP_URL}/api/health: HTTP $(health)  [200 = working, 503 = database is off]"
}

off() {
  echo "== 1/2 pausing the scheduled jobs"
  for j in "${JOBS[@]}"; do g scheduler jobs pause "$j" --location "$REGION" >/dev/null && echo "   $j: paused"; done
  echo "== 2/2 stopping Cloud SQL (takes a minute)"
  g sql instances patch "$SQL_INSTANCE" --activation-policy NEVER --quiet >/dev/null
  echo "   $SQL_INSTANCE: $(sql_state)"
  echo "Off. Turn it on again with: bash scripts/power.sh on"
}

on() {
  echo "== 1/3 starting Cloud SQL (takes one to three minutes)"
  g sql instances patch "$SQL_INSTANCE" --activation-policy ALWAYS --quiet >/dev/null
  for i in $(seq 1 30); do
    [ "$(sql_state)" = "RUNNABLE" ] && break
    [ "$i" = 30 ] && { echo "   Cloud SQL did not become ready in time; run 'bash scripts/power.sh status' in a minute."; exit 1; }
    sleep 10
  done
  echo "   $SQL_INSTANCE: $(sql_state)"
  echo "== 2/3 resuming the scheduled jobs"
  for j in "${JOBS[@]}"; do g scheduler jobs resume "$j" --location "$REGION" >/dev/null && echo "   $j: resumed"; done
  echo "== 3/3 checking that the web answers (the first request after a long pause is slow)"
  for i in $(seq 1 12); do
    code="$(health)"
    [ "$code" = "200" ] && { echo "   ${APP_URL}/api/health: ok"; echo "On."; return 0; }
    sleep 10
  done
  echo "   the web has not answered 200 yet (last answer: HTTP $code). Wait a minute and run: bash scripts/power.sh status"
  exit 1
}

case "${1:-}" in
  status) status ;;
  off) off ;;
  on) on ;;
  *) echo "Usage: bash scripts/power.sh status|off|on"; exit 1 ;;
esac
