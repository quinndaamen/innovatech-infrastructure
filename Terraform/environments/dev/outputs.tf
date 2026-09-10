output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = module.compute.alb_dns_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.compute.ecr_repository_url
}

output "compute_vpc_id" {
  description = "ID of the Compute VPC"
  value       = module.network.compute_vpc_id
}