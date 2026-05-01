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
echo "Cloud SQL, Cloud Run, VPC, Secrets, Artifact Registry..."
echo ""
read -r -p "Type 'destroy' to confirm: " CONFIRM
if [[ "$CONFIRM" != "destroy" ]]; then
  echo "Aborted."
  exit 1
fi

cd "$TERRAFORM_DIR"

# Pre-remove resources that GCP cannot delete via API while dependent services
# are still shutting down. The parent resource (Cloud SQL instance / VPC) will
# cascade-clean them when it is deleted.
echo ""
echo "--> Pre-removing GCP-blocked resources from state..."
for resource in \
  google_sql_database.database \
  google_sql_user.postgres \
  google_service_networking_connection.private_vpc_connection; do
  if terraform state list | grep -q "^${resource}$"; then
    terraform state rm "$resource"
    echo "    removed $resource"
  fi
done

echo ""
echo "--> Running terraform destroy..."
terraform destroy -auto-approve

echo ""
echo "========================================"
echo "  All resources deleted."
echo "  Run scripts/demo-restore.sh to restore."
echo "========================================"
