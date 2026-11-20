variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "zone" {
  type        = string
  description = "Zone of the cluster and node pool"
}

variable "network" {
  type        = string
  description = "ID of the VPC"
}

variable "subnetwork" {
  type        = string
  description = "ID of the GKE subnet"
}

variable "pods_name" {
  type        = string
  description = "Name of the secondary range for pods"
}

variable "services_name" {
  type        = string
  description = "Name of the secondary range for services"
}

variable "myip" {
  type        = string
  description = "CIDR allowed to reach the Kubernetes API"
}

variable "node_tags" {
  type = list(string)
}