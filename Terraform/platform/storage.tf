# Archive of home folders of offboarded employees (REQ-13: cheap storage for rarely read data)
data "google_project" "this" {
  project_id = var.project_id
}

resource "google_storage_bucket" "home_archives" {
  name                        = "${var.project_id}-home-archives"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  lifecycle_rule {
    condition { age = 30 }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }
  lifecycle_rule {
    condition { age = 365 }
    action { type = "Delete" }
  }
}

# The archive Job runs as Kubernetes service account desktops/archiver. With Workload Identity
# that account can be granted access directly, without a Google service account.
resource "google_storage_bucket_iam_member" "archiver" {
  bucket = google_storage_bucket.home_archives.name
  role   = "roles/storage.objectCreator"
  member = "principal://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/desktops/sa/archiver"
}
