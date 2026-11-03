output "onprem_instance_id" {
  description = "ID of the simulated on-premises Ubuntu server"
  value       = aws_instance.onprem_server.id
}

output "onprem_private_ip" {
  description = "Private IP address of the simulated on-premises server"
  value       = aws_instance.onprem_server.private_ip
}