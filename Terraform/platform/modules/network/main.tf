# VPC
resource "google_compute_network" "innovatech_vpc" {
  name = "innovatech-vpc"
  auto_create_subnetworks = false
}

# Subnets
resource "google_compute_subnetwork" "gke_subnet" {
  name          = var.nodes_name
  ip_cidr_range = var.nodes_cidr
  region        = var.region
  network       = google_compute_network.innovatech_vpc.id

  private_ip_google_access = true
  secondary_ip_range {
    range_name    = var.pods_name
    ip_cidr_range = var.pods_cidr
  }
  secondary_ip_range {
    range_name    = var.services_name
    ip_cidr_range = var.services_cidr
  }

}

# Router
resource "google_compute_router" "innovatech_router" {
  name    = "innovatech-router"
  network = google_compute_network.innovatech_vpc.id
  region = var.region

}

# NAT gateway
resource "google_compute_router_nat" "innovatech_nat" {
  name                               = "innovatech-nat"
  router                             = google_compute_router.innovatech_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_firewall" "innovatech_firewall" {
  name    = "innovatech-deny-all-ingress"
  network = google_compute_network.innovatech_vpc.id
  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  priority = 65534

  deny {
    protocol = "all"
    }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
  
}


