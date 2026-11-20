resource "google_artifact_registry_repository" "innovatech_repository" {
  location      = var.region
  repository_id = "innovatech-desktops-images"
  description   = "innovatech docker repository"
  format        = "DOCKER"

  docker_config { immutable_tags = true }

  depends_on = [google_project_service.apis]

  # lifecycle {
  #   prevent_destroy = true
  # }
}
