resource "google_compute_global_address" "innovatech_private_ip_db" {

  name          = "innovatech-private-ip-db"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address = var.address
  prefix_length = 20
  network       = var.network
}

resource "google_service_networking_connection" "innovatech_private_connection" {

  network                 = var.network
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.innovatech_private_ip_db.name]
}

resource "google_sql_database_instance" "innovatech_database" {
  name             = "innovatech-database"
  database_version = "POSTGRES_17"
  region           = var.region
  deletion_protection = true



  settings {
    edition = "ENTERPRISE"
    deletion_protection_enabled = true
    backup_configuration {
      enabled = true
    }
    ip_configuration {
      private_network = var.network
      ipv4_enabled = false
    }
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    tier = "db-f1-micro"
  }

  depends_on = [google_service_networking_connection.innovatech_private_connection]
}

# Portal database configuration
resource "random_password" "innovatech_portal_db" {
  length  = 24
  special = false      # avoids characters that break connection strings
}

resource "google_secret_manager_secret_version" "innovatech_portal_db_password" {
  secret      = google_secret_manager_secret.innovatech_portal_db_password.id
  secret_data = random_password.innovatech_portal_db.result
}

resource "google_sql_user" "innovatech_portal_db_user" {
  name     = "portal"
  instance = google_sql_database_instance.innovatech_database.name
  password = random_password.innovatech_portal_db.result
}

resource "google_secret_manager_secret" "innovatech_portal_db_password" {
  secret_id = "innovatech-portal-db-password"
  

  replication {
    user_managed {
      replicas {
        location = var.region    # keeps the secret in the EU
      }
    }
  }
}


resource "google_sql_database" "innovatech_portal_database" {
  name     = "portal"
  instance = google_sql_database_instance.innovatech_database.name
}



# Keycloak database configuration
resource "random_password" "innovatech_keycloak_db" {
  length  = 24
  special = false      # avoids characters that break connection strings
}

resource "google_secret_manager_secret_version" "innovatech_keycloak_db_password" {
  secret      = google_secret_manager_secret.innovatech_keycloak_db_password.id
  secret_data = random_password.innovatech_keycloak_db.result
}

resource "google_sql_user" "innovatech_keycloak_db_user" {
  name     = "keycloak"
  instance = google_sql_database_instance.innovatech_database.name
  password = random_password.innovatech_keycloak_db.result
}

resource "google_secret_manager_secret" "innovatech_keycloak_db_password" {
  secret_id = "innovatech-keycloak-db-password"
  

  replication {
    user_managed {
      replicas {
        location = var.region    # keeps the secret in the EU
      }
    }
  }
}

resource "google_sql_database" "innovatech_keycloak_database" {
  name     = "keycloak"
  instance = google_sql_database_instance.innovatech_database.name
}
