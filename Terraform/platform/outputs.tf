output "dns_name_servers" {
  description = "DNS name servers for Innovatech"
  value       = google_dns_managed_zone.innovatech_zone.name_servers
}