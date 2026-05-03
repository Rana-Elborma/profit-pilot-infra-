#!/usr/bin/env bash
# demo-restore.sh — restore the entire cloud environment from code
# Usage: bash scripts/demo-restore.sh
#
# Prerequisites:
#   - gcloud auth application-default login
#   - gh auth login   (GitHub CLI, for auto-updating secrets)
#   - terraform installed
#   - terraform.tfvars present in ./terraform/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TERRAFORM_DIR="$REPO_ROOT/terraform"
SERVICES_REPO="Rana-Elborma/profit-pilot-services"

echo "========================================"
echo "  PROFIT PILOT — RESTORE"
echo "========================================"
echo ""
echo "Step 1/4 — Provisioning infrastructure..."
echo ""

cd "$TERRAFORM_DIR"

# Firestore databases survive terraform destroy (GCP restriction).
# Import it into state if it already exists so apply doesn't fail.
if ! terraform state list 2>/dev/null | grep -q "google_firestore_database.default"; then
  terraform import google_firestore_database.default "(default)" 2>/dev/null || true
fi

terraform apply -auto-approve

echo ""
echo "Step 2/4 — Reading outputs..."

PROJECT_ID=$(terraform output -raw gcp_project_id)
REGION=$(terraform output -raw gcp_region)
REGISTRY=$(terraform output -raw artifact_registry_url)
CORE_URL=$(terraform output -raw core_api_url)
ANALYTICS_URL=$(terraform output -raw analytics_api_url)
WIF_PROVIDER=$(terraform output -raw wif_provider)
WIF_SA=$(terraform output -raw service_account_email)

echo "  project_id:        $PROJECT_ID"
echo "  region:            $REGION"
echo "  artifact_registry: $REGISTRY"
echo "  core_api_url:      $CORE_URL"
echo "  analytics_api_url: $ANALYTICS_URL"
echo "  wif_provider:      $WIF_PROVIDER"
echo "  service_account:   $WIF_SA"

echo ""
echo "Step 3/4 — Updating GitHub Secrets on $SERVICES_REPO ..."

if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
  gh secret set GCP_PROJECT_ID        --body "$PROJECT_ID"   --repo "$SERVICES_REPO"
  gh secret set GCP_REGION            --body "$REGION"       --repo "$SERVICES_REPO"
  gh secret set WIF_PROVIDER          --body "$WIF_PROVIDER" --repo "$SERVICES_REPO"
  gh secret set WIF_SERVICE_ACCOUNT   --body "$WIF_SA"       --repo "$SERVICES_REPO"
  gh secret set ARTIFACT_REGISTRY     --body "$REGISTRY"     --repo "$SERVICES_REPO"
  echo "  GitHub secrets updated on $SERVICES_REPO"
else
  echo "  gh CLI not found or not authenticated — update these secrets manually:"
  echo ""
  echo "  Repo: github.com/$SERVICES_REPO"
  echo "  Settings → Secrets and variables → Actions → update each one:"
  echo ""
  echo "  GCP_PROJECT_ID      = $PROJECT_ID"
  echo "  GCP_REGION          = $REGION"
  echo "  WIF_PROVIDER        = $WIF_PROVIDER"
  echo "  WIF_SERVICE_ACCOUNT = $WIF_SA"
  echo "  ARTIFACT_REGISTRY   = $REGISTRY"
  echo ""
  echo "  Press Enter when done..."
  read -r
fi

echo ""
echo "Step 4/4 — Deploying application images via CI/CD..."

if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
  gh workflow run "Deploy core-api"      --repo "$SERVICES_REPO" --ref main
  gh workflow run "Deploy analytics-api" --repo "$SERVICES_REPO" --ref main
  echo "  Workflows triggered — waiting for both to complete..."

  # Poll until both workflows finish
  sleep 15
  for workflow in "Deploy core-api" "Deploy analytics-api"; do
    echo "  Waiting for: $workflow"
    while true; do
      STATUS=$(gh run list --workflow="$workflow" --repo "$SERVICES_REPO" --limit 1 --json status,conclusion \
               --jq '.[0] | if .status == "completed" then .conclusion else .status end')
      if [[ "$STATUS" == "success" ]]; then
        echo "  ✓ $workflow — success"
        break
      elif [[ "$STATUS" == "failure" || "$STATUS" == "cancelled" ]]; then
        echo "  ✗ $workflow — $STATUS"
        echo "    Check: https://github.com/$SERVICES_REPO/actions"
        exit 1
      fi
      sleep 10
    done
  done
else
  echo "  gh CLI not available — trigger CI/CD manually:"
  echo "    https://github.com/$SERVICES_REPO/actions"
  echo "  Press Enter once both workflows are green..."
  read -r
fi

echo ""
echo "========================================"
echo "  RESTORE COMPLETE"
echo "========================================"
echo ""
echo "  core-api:      $CORE_URL"
echo "  analytics-api: $ANALYTICS_URL"
echo ""
echo "  Verify:"
echo "  curl $CORE_URL/docs"
echo "  curl $ANALYTICS_URL/docs"
echo ""
