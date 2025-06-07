output "Id" {
  value       = aws_route53_zone.zone.zone_id
}

output "Nameservers" {
  value       = var.Type == "Public" ? aws_route53_zone.zone.name_servers : []
}