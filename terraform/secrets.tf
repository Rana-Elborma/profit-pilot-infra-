# ── JWT secret (auto-generated) ───────────────────────────────────────────────

resource "random_password" "jwt_secret" {
  length  = 48
  special = false
}

# ── Secret: DATABASE_URL ──────────────────────────────────────────────────────

resource "google_secret_manager_secret" "database_url" {
  secret_id = "DATABASE_URL"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "database_url" {
  secret = google_secret_manager_secret.database_url.id

  secret_data = "postgresql://postgres:${random_password.db_password.result}@${google_sql_database_instance.db.private_ip_address}:5432/profitpilot"

  depends_on = [google_sql_database_instance.db]
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
