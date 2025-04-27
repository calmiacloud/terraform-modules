output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.this.id
}

output "subnets_public_ids" {
  description = "IDs de las subnets públicas"
  value       = { for az, subnet in aws_subnet.public : az => subnet.id }
}

output "internet_gateway_id" {
  description = "ID del Internet Gateway"
  value       = aws_internet_gateway.this.id
}

output "route_table_id" {
  description = "ID de la Route Table pública"
  value       = aws_route_table.public.id
}
