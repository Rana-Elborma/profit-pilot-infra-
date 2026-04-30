# ── Artifact Registry ────────────────────────────────────────────────────────
# Docker repository for both microservice images.
# Push URL: ${region}-docker.pkg.dev/${project_id}/profit-pilot/<image>:<tag>

resource "google_artifact_registry_repository" "profit_pilot" {
  location      = var.region
  repository_id = "profit-pilot"
  format        = "DOCKER"
  description   = "Docker images for Profit Pilot microservices"

  depends_on = [google_project_service.artifactregistry]
}
