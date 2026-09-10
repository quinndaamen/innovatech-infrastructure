variable "database_master_password" {
  description = "Master password for Aurora PostgreSQL"
  type        = string
  sensitive   = true
}