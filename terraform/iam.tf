# ── Project data (needed for Cloud Run service agent email) ───────────────────

data "google_project" "project" {
  depends_on = [google_project_service.cloudresourcemanager]
}

# ── CI/CD Service Account ─────────────────────────────────────────────────────

resource "google_service_account" "profit_pilot_sa" {
  account_id   = "profit-pilot-sa"
  display_name = "Profit Pilot CI/CD Service Account"
  depends_on   = [google_project_service.iam]
}

# ── Roles for the CI/CD service account ──────────────────────────────────────

resource "google_project_iam_member" "run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.profit_pilot_sa.email}"
}

resource "google_project_iam_member" "artifact_registry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.profit_pilot_sa.email}"
}

resource "google_project_iam_member" "secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.profit_pilot_sa.email}"
}

resource "google_project_iam_member" "firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.profit_pilot_sa.email}"
}

resource "google_project_iam_member" "service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.profit_pilot_sa.email}"
}

resource "google_project_iam_member" "storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.profit_pilot_sa.email}"
}

# ── Cloud Run service agent → Secret Manager access ───────────────────────────
# The serverless robot injects secret env-var values into containers at
# startup time; it needs secretAccessor to read the secret versions.

resource "google_project_iam_member" "cloud_run_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:service-${data.google_project.project.number}@serverless-robot-prod.iam.gserviceaccount.com"

  depends_on = [google_project_service.run]
}

# ── IAM propagation buffer ────────────────────────────────────────────────────
# GCP IAM bindings take ~20-30s to propagate globally after the API confirms
# creation. Cloud Run fails to mount secrets if it starts before propagation
# completes. This sleep ensures Cloud Run resources never start too early.

resource "time_sleep" "iam_propagation" {
  create_duration = "30s"

  depends_on = [
    google_project_iam_member.secret_accessor,
    google_project_iam_member.cloud_run_secret_accessor,
    google_project_iam_member.firestore_user,
  ]
}

# ── Workload Identity Federation — keyless GitHub Actions auth ───────────────
# SA key creation is blocked by org policy. WIF lets GitHub Actions authenticate
# directly via OIDC — no key file stored anywhere.
#
# GCP soft-deletes pool IDs for 30 days after destroy — the same name cannot be
# reused. A short random suffix ensures each restore cycle gets a unique ID.

resource "random_id" "wif_suffix" {
  byte_length = 3
}

resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = "pp-github-${random_id.wif_suffix.hex}"
  display_name              = "GitHub Actions Pool"
  depends_on                = [google_project_service.iamcredentials]
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "pp-github-provider-${random_id.wif_suffix.hex}"
  display_name                       = "GitHub Actions Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  # Only tokens from the specified repo are accepted
  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Allow the GitHub Actions workflow to impersonate the CI/CD service account
resource "google_service_account_iam_member" "github_wif_binding" {
  service_account_id = google_service_account.profit_pilot_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_repo}"
}
