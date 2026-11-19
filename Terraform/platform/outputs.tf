output "dns_name_servers" {
  description = "Nameservers for Innovatech DNS delegation"
  value       = module.network.dns_name_servers
}