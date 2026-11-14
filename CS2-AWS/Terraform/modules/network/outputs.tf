output "compute_vpc_id" {
  description = "ID of the Compute VPC"
  value       = aws_vpc.compute.id
}

output "database_vpc_id" {
  description = "ID of the Database VPC"
  value       = aws_vpc.database.id
}

output "monitoring_vpc_id" {
  description = "ID of the Monitoring VPC"
  value       = aws_vpc.monitoring.id
}

output "compute_public_subnet_ids" {
  description = "IDs of the public Compute VPC subnets"

  value = [
    aws_subnet.compute_public_1.id,
    aws_subnet.compute_public_2.id
  ]
}

output "compute_private_subnet_ids" {
  description = "IDs of the private Compute VPC subnets"

  value = [
    aws_subnet.compute_private_1.id,
    aws_subnet.compute_private_2.id
  ]
}

output "database_private_subnet_ids" {
  description = "IDs of the private Database VPC subnets"
  value = [
    aws_subnet.database_private_1.id,
    aws_subnet.database_private_2.id
  ]
}


output "monitoring_private_subnet_ids" {
  description = "IDs of the private Monitoring VPC subnets"
  value = [
    aws_subnet.monitoring_private_1.id,
    aws_subnet.monitoring_private_2.id
  ]
}

output "onprem_vpc_id" {
  description = "ID of the simulated on-premises VPC"
  value       = aws_vpc.onprem.id
}

output "onprem_private_subnet_ids" {
  description = "IDs of the private on-premises subnets"
  value = [
    aws_subnet.onprem_private_1.id,
    aws_subnet.onprem_private_2.id
  ]
}

output "onprem_public_subnet_id" {
  description = "Public subnet ID for the simulated on-premises server"
  value       = aws_subnet.onprem_public.id
}