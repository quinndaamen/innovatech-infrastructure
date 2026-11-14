output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "ipsec_instance_id" {
  description = "EC2 instance ID of the IPsec VPN server"
  value       = aws_instance.ipsec.id
}

output "ipsec_public_ip" {
  description = "Public IP address of the IPsec VPN server"
  value       = aws_instance.ipsec.public_ip
}

output "ipsec_private_ip" {
  description = "Private IP address of the IPsec VPN server"
  value       = aws_instance.ipsec.private_ip
}