#!/usr/bin/env bash
# Checks that a running revision answers as the app. A healthy server is not enough: a release that lost
# routes once still answered /api/health, so four routes must also answer as themselves (anything but 404).
#   bash scripts/ci/smoke-test.sh https://<revision or service url>
set -euo pipefail
URL="${1:?usage: smoke-test.sh <base url>}"

code=000
for i in $(seq 1 12); do # the first request after scale-to-zero is slow
  code="$(curl -s -m 60 -o /dev/null -w '%{http_code}' "${URL}/api/health" || true)"
  [ "$code" = "200" ] && break
  sleep 5
done
if [ "$code" != "200" ]; then
  echo "  FAIL  /api/health answered ${code}"
  exit 1
fi
echo "  ok    /api/health"

expect() { # method, path, accepted statuses (a|b), label
  local got
  got="$(curl -s -m 60 -o /dev/null -w '%{http_code}' -X "$1" -H 'Content-Type: application/json' -d '{}' "${URL}$2")"
  if [[ "$got" =~ ^($3)$ ]]; then
    echo "  ok    $4 ($1 $2 -> $got)"
  else
    echo "  FAIL  $4 ($1 $2 -> $got, expected $3): the release is missing a route"
    exit 1
  fi
}
expect POST /api/mobile/auth/login 400 "phone app sign-in refuses an empty request"
expect GET /api/mobile/surveys "400|401" "phone app survey list needs a token"
expect POST /api/public-responses 400 "public survey intake refuses an empty answer"
expect POST /api/internal/jobs/field-alerts 401 "background job endpoint needs the scheduler secret"
