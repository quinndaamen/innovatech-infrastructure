resource "google_service_account" "gke_portal_nodes" {
  account_id   = "innovatech-gke-portal"
  display_name = "GKE portal node pool"
}

resource "google_project_iam_member" "gke_portal_nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
  ])

  project = var.project_id
  role    = each.value
  member  = google_service_account.gke_portal_nodes.member
}