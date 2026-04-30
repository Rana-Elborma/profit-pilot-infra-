variable "project_id" {
  description = "GCP project ID where all resources will be provisioned"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "us-central1"
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format (e.g. ranamahmoud/profit-pilot)"
  type        = string
}
