# ── Service Networking API ───────────────────────────────────────────────────
# Required to peer the VPC with Google's managed services network so that
# Cloud SQL can be assigned a private IP reachable from within the VPC.

resource "google_project_service" "servicenetworking" {
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
  depends_on         = [google_project_service.cloudresourcemanager]
}

# ── Private IP range for Google-managed services ─────────────────────────────

resource "google_compute_global_address" "private_ip_range" {
  name          = "profit-pilot-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

# ── VPC peering with Google service producers (Cloud SQL, etc.) ───────────────

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]

  depends_on = [google_project_service.servicenetworking]
}

# ── Database password (auto-generated, never hardcoded) ──────────────────────

resource "random_password" "db_password" {
  length  = 24
  special = false
}

# ── Cloud SQL PostgreSQL instance ─────────────────────────────────────────────

resource "google_sql_database_instance" "db" {
  name             = "profit-pilot-db"
  database_version = "POSTGRES_15"
  region           = var.region

  # deletion_protection = false so `terraform destroy` works in the demo.
  # Set to true before any production use.
  deletion_protection = false

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled    = false # private IP only — no public endpoint
      private_network = google_compute_network.vpc.self_link
      allocated_ip_range = google_compute_global_address.private_ip_range.name
    }

    backup_configuration {
      enabled = true
    }
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# ── Database ──────────────────────────────────────────────────────────────────

resource "google_sql_database" "database" {
  name     = "profitpilot"
  instance = google_sql_database_instance.db.name
}

# ── Database user ─────────────────────────────────────────────────────────────

resource "google_sql_user" "postgres" {
  name     = "postgres"
  instance = google_sql_database_instance.db.name
  password = random_password.db_password.result
}
