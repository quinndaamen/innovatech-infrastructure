output "onprem_instance_id" {
  description = "ID of the simulated on-premises Ubuntu server"
  value       = aws_instance.onprem_server.id
}

output "onprem_private_ip" {
  description = "Private IP address of the simulated on-premises server"
  value       = aws_instance.onprem_server.private_ip
}

output "windows_instance_id" {
  description = "ID of the simulated on-premises Windows server"
  value       = aws_instance.onprem_windows.id
}

output "windows_private_ip" {
  description = "Private IP of the Windows server"
  value       = aws_instance.onprem_windows.private_ip
}

output "windows_public_ip" {
  description = "Public IP of the Windows server"
  value       = aws_instance.onprem_windows.public_ip
}