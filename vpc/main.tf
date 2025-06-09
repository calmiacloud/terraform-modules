##############################
# VPC Block
##############################

resource "aws_vpc" "vpc" {
  cidr_block                     = var.Vpc.Cidr
  enable_dns_support             = true
  enable_dns_hostnames           = true
  assign_generated_ipv6_cidr_block = var.Vpc.Ipv6Support
  tags = merge(var.Tags, {
    Name = "Vpc${var.Name}"
  })
}

##############################
# Subnets
##############################

##############################
# Subnets
##############################

resource "aws_subnet" "subnet_public" {
  count = length(flatten([for key, value in var.Subnets.Public : value])) > 0 ? length(flatten([for key, value in var.Subnets.Public : value])) : 0
  vpc_id = aws_vpc.vpc.id
  cidr_block = flatten([for key, value in var.Subnets.Public : value])[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  ipv6_cidr_block = var.Vpc.Ipv6Support ? cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, count.index) : null
  assign_ipv6_address_on_creation = var.Vpc.Ipv6Support ? true : null
  tags = merge(
    { Name = "SubnetPublic${flatten([for key, value in var.Subnets.Public : value])[count.index]}Az${count.index}" },
    var.Tags
  )
  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_subnet" "subnet_nat" {
  count = length(flatten([for key, value in var.Subnets.Nat : value])) > 0 ? length(flatten([for key, value in var.Subnets.Nat : value])) : 0
  vpc_id = aws_vpc.vpc.id
  cidr_block = flatten([for key, value in var.Subnets.Nat : value])[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = false
  tags = merge(
    { Name = "SubnetNat${flatten([for key, value in var.Subnets.Nat : value])[count.index]}Az${count.index}" },
    var.Tags
  )
  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_subnet" "subnet_private" {
  count = length(flatten([for key, value in var.Subnets.Private : value])) > 0 ? length(flatten([for key, value in var.Subnets.Private : value])) : 0
  vpc_id = aws_vpc.vpc.id
  cidr_block = flatten([for key, value in var.Subnets.Private : value])[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = merge(
    { Name = "SubnetPrivate${flatten([for key, value in var.Subnets.Private : value])[count.index]}Az${count.index}" },
    var.Tags
  )
  lifecycle {
    create_before_destroy = false
  }
}

##############################
# Gateways
##############################

resource "aws_internet_gateway" "ig_internet" {
  count  = length(flatten([for key, value in var.Subnets.Public : value])) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  tags = merge(var.Tags, {
    Name = "Ig${var.Name}"
  })
}

resource "aws_eip" "eip_ig_nat" {
  count  = length(flatten([for key, value in var.Subnets.Nat : value])) > 0 ? 1 : 0
  domain = "vpc"
  tags = merge(var.Tags, {
    Name = "EipIgn${var.Name}"
  })
}

resource "aws_nat_gateway" "ig_nat" {
  count         = length(flatten([for key, value in var.Subnets.Nat : value])) > 0 ? 1 : 0
  allocation_id = aws_eip.eip_ig_nat[0].id
  subnet_id     = aws_subnet.subnet_public[0].id
  tags = merge(var.Tags, {
    Name = "Ign${var.Name}"
  })
}

#################################
# Route tables
##################################

resource "aws_route_table" "rt_public" {
  count  = length(flatten([for key, value in var.Subnets.Public : value])) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig_internet[0].id
  }
  dynamic "route" {
    for_each = var.Vpc.Ipv6Support ? [1] : []
    content {
      ipv6_cidr_block = "::/0"
      gateway_id      = aws_internet_gateway.ig_internet[0].id
    }
  }
  tags = merge(var.Tags, {
    Name = "RtPublic${var.Name}"
  })
}

resource "aws_route_table" "rt_nat" {
  count  = length(flatten([for key, value in var.Subnets.Nat : value])) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  # Ruta por defecto a NAT GW
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ig_nat[0].id
  }
  tags = merge(var.Tags, {
    Name = "RtNat${var.Name}"
  })
}

resource "aws_route_table" "rt_private" {
  count  = length(flatten([for key, value in var.Subnets.Private : value])) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  tags = merge(var.Tags, {
    Name = "RtPrivate${var.Name}"
  })
}

#################################
# Route table associations
##################################

resource "aws_route_table_association" "public" {
  count          = length(flatten([for key, value in var.Subnets.Public : value]))
  subnet_id      = aws_subnet.subnet_public[count.index].id
  route_table_id = aws_route_table.rt_public[0].id
}

resource "aws_route_table_association" "nat" {
  count          = length(flatten([for key, value in var.Subnets.Nat : value]))
  subnet_id      = aws_subnet.subnet_nat[count.index].id
  route_table_id = aws_route_table.rt_nat[0].id
}

resource "aws_route_table_association" "private" {
  count          = length(flatten([for key, value in var.Subnets.Private : value]))
  subnet_id      = aws_subnet.subnet_private[count.index].id
  route_table_id = aws_route_table.rt_private[0].id
}