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

#Desktop service acount
resource "google_service_account" "gke_desktop_nodes" {
  account_id   = "innovatech-gke-desktop"
  display_name = "GKE desktop node pool"
}

resource "google_project_iam_member" "gke_desktop_nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
  ])

  project = var.project_id
  role    = each.value
  member  = google_service_account.gke_desktop_nodes.member
}