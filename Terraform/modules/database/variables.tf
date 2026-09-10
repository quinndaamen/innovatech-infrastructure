variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "ID of the Database VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Aurora"
  type        = list(string)
}

variable "allowed_web_subnet_cidrs" {
  description = "Private Compute subnet CIDRs allowed to access Aurora"
  type        = list(string)
}

variable "database_name" {
  description = "Initial Aurora database name"
  type        = string
  default     = "innovatech"
}

variable "master_username" {
  description = "Aurora master username"
  type        = string
  default     = "innovatech_admin"
}

variable "master_password" {
  description = "Aurora master password"
  type        = string
  sensitive   = true
}