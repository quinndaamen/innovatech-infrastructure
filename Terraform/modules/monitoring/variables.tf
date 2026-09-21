variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "ID of the Monitoring VPC"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet for the monitoring server"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for monitoring"
  type        = string
  default     = "t3.small"
}

variable "prometheus_version" {
  description = "Prometheus version"
  type        = string
  default     = "3.5.0"
}

variable "grafana_version" {
  description = "Grafana version"
  type        = string
  default     = "13.2.2"
}