output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "wireguard_instance_id" {
  description = "EC2 instance ID of the WireGuard VPN server"
  value       = aws_instance.wireguard.id
}

output "wireguard_public_ip" {
  description = "Public IP address of the WireGuard VPN server"
  value       = aws_instance.wireguard.public_ip
}

output "wireguard_private_ip" {
  description = "Private IP address of the WireGuard VPN server"
  value       = aws_instance.wireguard.private_ip
}