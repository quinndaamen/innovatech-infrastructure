variable "compute_vpc_cidr" {
  description = "CIDR block for the Compute VPC"
  type        = string
}

variable "database_vpc_cidr" {
  description = "CIDR block for the Database VPC"
  type        = string
}

variable "monitoring_vpc_cidr" {
  description = "CIDR block for the Monitoring VPC"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}