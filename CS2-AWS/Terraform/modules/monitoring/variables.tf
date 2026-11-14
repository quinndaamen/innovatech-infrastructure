variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "ID of the Monitoring VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets used by the Elastic Stack instances"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least two private subnet IDs must be provided."
  }
}

variable "elasticsearch_instance_type" {
  description = "EC2 instance type for Elasticsearch"
  type        = string
  default     = "t3.medium"
}

variable "logstash_instance_type" {
  description = "EC2 instance type for Logstash"
  type        = string
  default     = "t3.small"
}

variable "kibana_instance_type" {
  description = "EC2 instance type for Kibana"
  type        = string
  default     = "t3.small"
}

variable "elasticsearch_volume_size" {
  description = "Root volume size for Elasticsearch in GB"
  type        = number
  default     = 50
}

variable "logstash_volume_size" {
  description = "Root volume size for Logstash in GB"
  type        = number
  default     = 20
}

variable "kibana_volume_size" {
  description = "Root volume size for Kibana in GB"
  type        = number
  default     = 20
}

variable "elastic_version" {
  description = "Version shared by Elasticsearch, Logstash, and Kibana"
  type        = string
  default     = "9.5.5"
}

variable "aws_region" {
  description = "AWS region where the Elastic Stack is deployed"
  type        = string
  default     = "eu-central-1"
}