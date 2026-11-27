resource "google_storage_bucket_iam_member" "archiver_viewer" {
  bucket = google_storage_bucket.home_archives.name
  role   = "roles/storage.objectViewer"

  member = "principal://iam.googleapis.com/projects/4275750105/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/desktops/sa/archiver"
}