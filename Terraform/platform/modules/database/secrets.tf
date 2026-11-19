resource "google_secret_manager_secret" "innovatech_secrets" {
  secret_id = "innovatech-secrets"
  
  labels = {
    label = ""
  }

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  deletion_protection = true
}
