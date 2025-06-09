output "Id" {
  value = aws_vpc.vpc.id
}

output "SubnetPublic" {
  value = {
    for idx, cidr in flatten([for name, cidrs in var.Subnets.Public : [
      for i, c in cidrs : "${name}-${i}"
    ]]) :
    cidr => aws_subnet.subnet_public[idx].id
  }
}

output "SubnetNat" {
  value = {
    for idx, cidr in flatten([for name, cidrs in lookup(var.Subnets, "Nat", {}) : [
      for i, c in cidrs : "${name}-${i}"
    ]]) :
    cidr => aws_subnet.subnet_nat[idx].id
  }
}

output "SubnetPrivate" {
  value = {
    for idx, cidr in flatten([for name, cidrs in lookup(var.Subnets, "Private", {}) : [
      for i, c in cidrs : "${name}-${i}"
    ]]) :
    cidr => aws_subnet.subnet_private[idx].id
  }
}