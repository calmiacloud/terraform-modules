output "Id" {
  value = aws_vpc.vpc.id
}

output "SubnetPublic" {
  value = {
    for idx in range(length(var.Subnets.Public)) :
    var.Subnets.Public[idx].Name => aws_subnet.subnet_public[idx].id
  }
}

output "SubnetNat" {
  value = {
    for idx in range(length(var.Subnets.Nat)) :
    var.Subnets.Nat[idx].Name => aws_subnet.subnet_nat[idx].id
  }
}

output "SubnetPrivate" {
  value = {
    for name, subnet in aws_subnet.subnet_private :
    name => subnet.id
  }
}