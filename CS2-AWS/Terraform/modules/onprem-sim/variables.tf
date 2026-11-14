variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "ID of the simulated on-premises VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the simulated on-premises environment"
  type        = list(string)
}

variable "public_subnet_id" {
  description = "Public subnet ID for the simulated on-premises server"
  type        = string
}