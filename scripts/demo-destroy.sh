#!/usr/bin/env bash
# demo-destroy.sh — wipe the entire cloud environment
# Usage: bash scripts/demo-destroy.sh

set -euo pipefail

TERRAFORM_DIR="$(cd "$(dirname "$0")/../terraform" && pwd)"

echo "========================================"
echo "  PROFIT PILOT — DESTROY"
echo "========================================"
echo ""
echo "This will DELETE all GCP resources for Profit Pilot."
echo "Cloud Run, Firestore, Secrets, Artifact Registry..."
echo ""
read -r -p "Type 'destroy' to confirm: " CONFIRM
if [[ "$CONFIRM" != "destroy" ]]; then
  echo "Aborted."
  exit 1
fi

cd "$TERRAFORM_DIR"
terraform destroy -auto-approve

echo ""
echo "========================================"
echo "  All resources deleted."
echo "  Run scripts/demo-restore.sh to restore."
echo "========================================"
