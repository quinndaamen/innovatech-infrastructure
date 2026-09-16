variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "ID of the Compute VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the Application Load Balancer"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "database_endpoint" {
  description = "Aurora PostgreSQL endpoint"
  type        = string
}

variable "database_port" {
  description = "Aurora PostgreSQL port"
  type        = number
}

variable "database_name" {
  description = "Application database name"
  type        = string
}

variable "database_username" {
  description = "Aurora database username"
  type        = string
}
variable "database_secret_arn" {
  description = "ARN of the database credentials secret"
  type        = string
}