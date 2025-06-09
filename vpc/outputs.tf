output "Id" {
  value = aws_vpc.vpc.id
}

output "SubnetPublic" {
  value = {
    for name, cidrs in var.Subnets.Public :
    name => [
      for i in range(length(cidrs)) :
      aws_subnet.subnet_public[sum([for n, c in var.Subnets.Public : n == name ? length(c) : 0]) - length(cidrs) + i].id
    ]
  }
}

output "SubnetNat" {
  value = {
    for name, cidrs in lookup(var.Subnets, "Nat", {}) :
    name => [
      for i in range(length(cidrs)) :
      aws_subnet.subnet_nat[sum([for n, c in lookup(var.Subnets, "Nat", {}) : n == name ? length(c) : 0]) - length(cidrs) + i].id
    ]
  }
}

output "SubnetPrivate" {
  value = {
    for name, cidrs in lookup(var.Subnets, "Private", {}) :
    name => [
      for i in range(length(cidrs)) :
      aws_subnet.subnet_private[sum([for n, c in lookup(var.Subnets, "Private", {}) : n == name ? length(c) : 0]) - length(cidrs) + i].id
    ]
  }
}
