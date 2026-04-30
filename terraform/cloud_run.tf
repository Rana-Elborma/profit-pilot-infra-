# ── Cloud Run: core-api ───────────────────────────────────────────────────────

resource "google_cloud_run_v2_service" "core_api" {
  name     = "core-api"
  location = var.region

  template {
    service_account = google_service_account.profit_pilot_sa.email

    containers {
      # Placeholder for initial apply; CI/CD replaces this on first git push.
      image = "gcr.io/cloudrun/hello"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.database_url.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }

    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "PRIVATE_RANGES_ONLY"
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }

  depends_on = [
    google_secret_manager_secret_version.database_url,
    google_secret_manager_secret_version.jwt_secret,
    google_project_iam_member.cloud_run_secret_accessor,
    google_project_service.run,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "core_api_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.core_api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ── Cloud Run: analytics-api ──────────────────────────────────────────────────

resource "google_cloud_run_v2_service" "analytics_api" {
  name     = "analytics-api"
  location = var.region

  template {
    service_account = google_service_account.profit_pilot_sa.email

    containers {
      # Placeholder for initial apply; CI/CD replaces this on first git push.
      image = "gcr.io/cloudrun/hello"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.database_url.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }

    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "PRIVATE_RANGES_ONLY"
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }

  depends_on = [
    google_secret_manager_secret_version.database_url,
    google_secret_manager_secret_version.jwt_secret,
    google_project_iam_member.cloud_run_secret_accessor,
    google_project_service.run,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "analytics_api_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.analytics_api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}