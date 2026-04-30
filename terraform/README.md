# Profit Pilot — Terraform Infrastructure

Provisions the complete GCP infrastructure for the Profit Pilot project:
VPC, Cloud SQL (PostgreSQL 15), Artifact Registry, Secret Manager, two Cloud Run
services (core-api, analytics-api), and the CI/CD service account.

---

## Prerequisites

```bash
# 1. Authenticate with GCP
gcloud auth login
gcloud auth application-default login

# 2. Set your project
gcloud config set project <your-project-id>

# 3. Create the GCS bucket for Terraform state (one-time, done manually)
gcloud storage buckets create gs://profit-pilot-terraform-state \
  --location=us-central1 \
  --uniform-bucket-level-access

# 4. Copy the example vars file and fill it in
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set project_id (and optionally region)
```

---

## Deploy

```bash
# Initialise providers and remote state backend
terraform init

# Preview every resource that will be created
terraform plan

# Apply — takes ~10 minutes (Cloud SQL is the slow step)
terraform apply
```

---

## Get outputs for GitHub Secrets

After `terraform apply` completes, run these commands and paste the values
into your repository's **Settings → Secrets and variables → Actions**.

| GitHub Secret        | Command                                    |
|----------------------|--------------------------------------------|
| `GCP_PROJECT_ID`     | `terraform output gcp_project_id`          |
| `GCP_REGION`         | `terraform output gcp_region`              |
| `GCP_SA_KEY`         | `terraform output -raw gcp_sa_key`         |
| `ARTIFACT_REGISTRY`  | `terraform output artifact_registry_url`   |
| `CORE_API_URL`       | `terraform output core_api_url`            |
| `ANALYTICS_API_URL`  | `terraform output analytics_api_url`       |

> `GCP_SA_KEY` is the raw JSON key for the `profit-pilot-sa` service account.
> Treat it as a password — never commit it to source control.

---

## Push your first Docker image

Before the Cloud Run services can serve real traffic, build and push at least
one tagged image:

```bash
# Authenticate Docker with Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build and push core-api
docker build -t us-central1-docker.pkg.dev/<project-id>/profit-pilot/core-api:latest ./core-api
docker push       us-central1-docker.pkg.dev/<project-id>/profit-pilot/core-api:latest

# Build and push analytics-api
docker build -t us-central1-docker.pkg.dev/<project-id>/profit-pilot/analytics-api:latest ./analytics-api
docker push       us-central1-docker.pkg.dev/<project-id>/profit-pilot/analytics-api:latest
```

After the first `git push`, GitHub Actions will handle all subsequent deployments.

---

## Tear down everything

```bash
terraform destroy
```

> Cloud SQL has `deletion_protection = false` so `destroy` works without
> manual intervention. Re-enable it before any production use.

---

## Architecture

```
GitHub Actions (CI/CD)
        │  docker push + gcloud run deploy
        ▼
Artifact Registry  ──────────────────────────────────────────┐
                                                              │
Internet → Cloud Run (core-api)     ──┐                      │
Internet → Cloud Run (analytics-api) ─┤  VPC Access          │
                                      │  Connector           │
                                      ▼                       │
                             profit-pilot-vpc                 │
                                      │                       │
                                      ▼                       │
                             Cloud SQL (PostgreSQL 15)        │
                             private IP — no public endpoint  │
                                                              │
Secret Manager (DATABASE_URL, JWT_SECRET) ───────────────────┘
```

---

## File structure

| File                       | What it provisions                              |
|----------------------------|-------------------------------------------------|
| `main.tf`                  | Provider, backend, GCP API enablement           |
| `variables.tf`             | Input variable declarations                     |
| `terraform.tfvars.example` | Template for your local `terraform.tfvars`      |
| `vpc.tf`                   | VPC, subnet, VPC Access Connector               |
| `artifact_registry.tf`     | Docker image repository                         |
| `cloud_sql.tf`             | Private IP plumbing + PostgreSQL instance       |
| `secrets.tf`               | Secret Manager secrets (DATABASE_URL, JWT)      |
| `iam.tf`                   | CI/CD service account, roles, key export        |
| `cloud_run.tf`             | core-api and analytics-api Cloud Run services   |
| `outputs.tf`               | All values needed for GitHub Secrets            |
