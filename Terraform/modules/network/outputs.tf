output "compute_vpc_cidr" {
  description = "ID of the compute VPC"
  value       = aws_vpc.compute.id
}
output "database_vpc_cidr" {
  description = "ID of the Database VPC"
  value       = aws_vpc.database.id
}
output "monitoring_vpc_cidr" {
  description = "ID of the Monitoring VPC"
  value       = aws_vpc.monitoring.id
}