output "innovatech_vpc_id" {
  description = "ID of the VPC"
  value       = google_compute_network.innovatech_vpc.id
}

output "gke_subnet_id" {
  description = "ID of the gke subnet"
  value       = google_compute_subnetwork.gke_subnet.id
}

output "pods_range_name" {
  value = var.pods_name
}

output "services_range_name" {
  value = var.services_name
}
