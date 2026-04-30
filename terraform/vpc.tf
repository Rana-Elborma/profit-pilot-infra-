# ── VPC network ─────────────────────────────────────────────────────────────

resource "google_compute_network" "vpc" {
  name                    = "profit-pilot-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.vpcaccess]
}

# ── Subnet ──────────────────────────────────────────────────────────────────

resource "google_compute_subnetwork" "subnet" {
  name          = "profit-pilot-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# ── Serverless VPC Access Connector ─────────────────────────────────────────
# Bridges Cloud Run (serverless) to the VPC so services can reach Cloud SQL
# over its private IP without traversing the public internet.

resource "google_vpc_access_connector" "connector" {
  name          = "profit-pilot-connector"
  region        = var.region
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpc.name
  depends_on    = [google_project_service.vpcaccess]
}
