# GKE Cluster
resource "google_container_cluster" "innovatech_gke_cluster" {
  name     = "innovatech-gke-cluster"
  location = var.zone
  network = var.network
  subnetwork = var.subnetwork

  remove_default_node_pool = true
  initial_node_count = 1

  ip_allocation_policy {
    cluster_secondary_range_name = var.pods_name
    services_secondary_range_name = var.services_name
  }

  private_cluster_config {
    enable_private_nodes = true
    enable_private_endpoint = false
    master_ipv4_cidr_block = "172.16.0.0/28"
  }

  master_authorized_networks_config {
  cidr_blocks {
    cidr_block   = var.myip
    display_name = "my-ip"
  }
  }

  workload_identity_config {
  workload_pool = "${var.project_id}.svc.id.goog"
  }

  deletion_protection = false
  datapath_provider = "ADVANCED_DATAPATH"
}

# Portal node pool
resource "google_container_node_pool" "innovatech_portal_pool" {
  name       = "innovatech-portal-pool"
  location   = var.zone
  cluster    = google_container_cluster.innovatech_gke_cluster.id
  node_count = 1
  

  node_config {
    machine_type = "e2-standard-2"
    disk_size_gb = 50
    
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.gke_portal_nodes.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      workload = "portal"
    }
  }
  depends_on = [google_project_iam_member.gke_portal_nodes]
}

# Desktop node pool
resource "google_container_node_pool" "innovatech_desktop_pool" {
  name       = "innovatech-desktop-pool"
  location   = var.zone
  cluster    = google_container_cluster.innovatech_gke_cluster.id
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }
  
  node_config {
    machine_type = "e2-standard-2"
    disk_size_gb = 50
    spot = true
    taint {
      key    = "workload"
      value  = "desktop"
      effect = "NO_SCHEDULE"
    }
    
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.gke_desktop_nodes.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      workload = "desktop"
    }
  }
  depends_on = [google_project_iam_member.gke_desktop_nodes]
}