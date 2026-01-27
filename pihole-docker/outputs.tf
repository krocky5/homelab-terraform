output "pihole_ip" {
  description = "IP address of the PiHole server"
  value       = var.pihole_ip
}

output "pihole_web_url" {
  description = "PiHole web interface URL"
  value       = "http://${var.pihole_ip}/admin"
}

output "pihole_dns_server" {
  description = "DNS server address to configure on clients"
  value       = var.pihole_ip
}

output "connection_info" {
  description = "SSH connection information"
  value       = "ssh ${var.vm_user}@${var.pihole_ip}"
}
