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

echo "========================================"
echo "  PROFIT PILOT — RESTORE"
echo "========================================"
echo ""
echo "Step 1/4 — Provisioning infrastructure (Cloud SQL takes ~10 min)..."
echo ""

cd "$TERRAFORM_DIR"
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
echo "Step 3/4 — Updating GitHub Secrets..."

if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
  cd "$REPO_ROOT"
  GITHUB_REPO=$(git remote get-url origin | sed 's/.*github.com[:/]//' | sed 's/\.git$//')

  gh secret set GCP_PROJECT_ID        --body "$PROJECT_ID"   --repo "$GITHUB_REPO"
  gh secret set GCP_REGION            --body "$REGION"       --repo "$GITHUB_REPO"
  gh secret set WIF_PROVIDER          --body "$WIF_PROVIDER" --repo "$GITHUB_REPO"
  gh secret set WIF_SERVICE_ACCOUNT   --body "$WIF_SA"       --repo "$GITHUB_REPO"
  gh secret set ARTIFACT_REGISTRY_URL --body "$REGISTRY"     --repo "$GITHUB_REPO"

  echo "  GitHub secrets updated automatically."
else
  echo "  gh CLI not found or not authenticated — update these secrets manually:"
  echo ""
  echo "  GCP_PROJECT_ID        = $PROJECT_ID"
  echo "  GCP_REGION            = $REGION"
  echo "  WIF_PROVIDER          = $WIF_PROVIDER"
  echo "  WIF_SERVICE_ACCOUNT   = $WIF_SA"
  echo "  ARTIFACT_REGISTRY_URL = $REGISTRY"
  echo ""
  echo "  Settings → Secrets and variables → Actions → update each one above."
  echo "  Press Enter when done..."
  read -r
fi

echo ""
echo "Step 4/4 — Triggering CI/CD (builds and deploys both Docker images)..."
cd "$REPO_ROOT"
git commit --allow-empty -m "chore: restore — trigger CI/CD after infra rebuild"
git push origin main

echo ""
echo "========================================"
echo "  RESTORE COMPLETE"
echo "========================================"
echo ""
echo "  Watch the deployment:"
echo "  https://github.com/$GITHUB_REPO/actions"
echo ""
echo "  Once CI/CD finishes (3-5 min), verify:"
echo "  curl $CORE_URL/health"
echo "  curl $ANALYTICS_URL/health"
echo ""
