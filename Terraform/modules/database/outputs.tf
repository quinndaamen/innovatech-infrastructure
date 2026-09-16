output "aurora_endpoint" {
  description = "Aurora PostgreSQL cluster endpoint"
  value       = aws_rds_cluster.aurora.endpoint
}

output "aurora_port" {
  description = "Aurora PostgreSQL port"
  value       = aws_rds_cluster.aurora.port
}

output "database_name" {
  description = "Application database name"
  value       = var.database_name
}

output "database_username" {
  description = "Aurora database username"
  value       = var.master_username
}

output "database_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = aws_secretsmanager_secret.database.arn
}