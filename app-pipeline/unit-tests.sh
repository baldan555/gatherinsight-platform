#!/usr/bin/env bash
# The tests CI runs on every push: pure logic (engines, statistics, survey rules, i18n coverage, guards
# such as "every owner write is audited"). None of them needs a database, a running server or the phone
# app's code, so they run in a few seconds each on a clean checkout.
#   bash scripts/ci/unit-tests.sh
set -uo pipefail
cd "$(dirname "$0")/../.."

TESTS=(
  account-manage action-error analysis-extra answer-media audit-coverage basic-location basic-review basic-speeding
  call-link-peer call-number call-queue comparison create-own-project field-group-coverage forecast
  geo-area-engine geo-engines geo-incident-engine geo-incident-insights geo-inspection-engine
  geo-inspection-insights geo-line-engine geo-point-design geo-point-engine geo-point-insights
  geo-point-issues geo-sample-engine geo-sample-rounds-engine geo-traffic-analysis
  i18n office option-labels path-answers public-submit-rules question-crosstab question-map question-period
  question-insights question-trend question-viz estimator logic-test questionnaire-diff questionnaire-readiness response-trend spss-export stats stats-exports survey-channel survey-overview survey-question-quality survey-report-extra supervisor-menu
  temp-password trend-target voice-openrouter
)

# Anything that tries to reach a database fails fast instead of hanging.
export DATABASE_URL="${DATABASE_URL:-postgresql://ci:ci@127.0.0.1:1/ci}"

failed=()
started=$(date +%s)
for t in "${TESTS[@]}"; do
  s=$(date +%s)
  if out=$(npx tsx "scripts/$t.test.ts" 2>&1); then
    printf '  ok    %-28s %3ss\n' "$t" "$(( $(date +%s) - s ))"
  else
    printf '  FAIL  %-28s %3ss\n' "$t" "$(( $(date +%s) - s ))"
    echo "$out" | tail -25 | sed 's/^/        /'
    failed+=("$t")
  fi
done

total=${#TESTS[@]}
echo
echo "$(( total - ${#failed[@]} ))/$total test files passed in $(( $(date +%s) - started ))s"
if [ ${#failed[@]} -gt 0 ]; then
  echo "Failed: ${failed[*]}"
  exit 1
fi
