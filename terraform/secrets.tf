# ── JWT secret (auto-generated) ───────────────────────────────────────────────

resource "random_password" "jwt_secret" {
  length  = 48
  special = false
}

# ── Secret: JWT_SECRET ────────────────────────────────────────────────────────

resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "JWT_SECRET"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "jwt_secret" {
  secret      = google_secret_manager_secret.jwt_secret.id
  secret_data = random_password.jwt_secret.result
}
