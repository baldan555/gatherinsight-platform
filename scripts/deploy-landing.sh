#!/usr/bin/env bash
# Manual fallback for the landing page deploy. Normally a push to main does this through GitHub Actions
# (.github/workflows/landing.yml). Run from the repository root:
#   bash scripts/deploy-landing.sh
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-gatherinsight}"
REGION="${REGION:-asia-southeast1}"
SERVICE="${SERVICE:-gatherinsight-landing}"

cd "$(dirname "$0")/.."
gcloud run deploy "$SERVICE" \
  --project "$PROJECT_ID" --region "$REGION" \
  --source landing \
  --allow-unauthenticated \
  --port 8080 --memory 256Mi --cpu 1 \
  --min-instances 0 --max-instances 3 \
  --quiet
gcloud run services describe "$SERVICE" --project "$PROJECT_ID" --region "$REGION" --format="value(status.url)"
