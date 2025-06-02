##############################
# VPC Block
##############################

resource "aws_vpc" "vpc" {
  cidr_block                     = var.Vpc.Cidr
  enable_dns_support             = true
  enable_dns_hostnames           = var.Vpc.DnsSupport
  assign_generated_ipv6_cidr_block = var.Vpc.Ipv6Support
  tags = merge(var.Tags, {
    Name = "Vpc${var.Name}"
  })
}

##############################
# Subnets
##############################

resource "aws_subnet" "subnet_public" {
  count                     = length(var.Subnets.Public) > 0 ? length(var.Subnets.Public[0].Cidr) : 0
  vpc_id                    = aws_vpc.vpc.id
  cidr_block                = var.Subnets.Public[0].Cidr[count.index]
  availability_zone         = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch   = true
  ipv6_cidr_block           = var.Vpc.Ipv6Support ? cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, count.index) : null
  assign_ipv6_address_on_creation = var.Vpc.Ipv6Support ? true : null
  tags = merge(
    { Name = "SubnetPublic${var.Subnets.Public[0].Name}Az${count.index}" },
    var.Tags
  )
  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_subnet" "subnet_nat" {
  count             = length(var.Subnets.Nat) > 0 ? length(var.Subnets.Nat[0].Cidr) : 0
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.Subnets.Nat[0].Cidr[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = false
  tags = merge(
    { Name = "SubnetNat${var.Subnets.Nat[0].Name}Az${count.index}" },
    var.Tags
  )
  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_subnet" "subnet_private" {
  count             = length(var.Subnets.Private) > 0 ? length(var.Subnets.Private[0].Cidr) : 0
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.Subnets.Private[0].Cidr[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = merge(
    { Name = "SubnetPrivate${var.Subnets.Private[0].Name}Az${count.index}" },
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
  count  = length(var.Subnets.Public) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  tags = merge(var.Tags, {
    Name = "Ig${var.Name}"
  })
}

resource "aws_eip" "eip_ig_nat" {
  count  = length(var.Subnets.Nat) > 0 ? 1 : 0
  domain = "vpc"
  tags = merge(var.Tags, {
    Name = "EipIgn${var.Name}"
  })
}

resource "aws_nat_gateway" "ig_nat" {
  count         = length(var.Subnets.Nat) > 0 ? 1 : 0
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
  count  = length(var.Subnets.Public) > 0 ? 1 : 0
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
  dynamic "route" {
    for_each = flatten([
      for s in var.Subnets.Public : lookup(s, "AdditionalRoutes", [])
    ])
    content {
      cidr_block = lookup(route.value, "Cidr", null)
      network_interface_id      = route.value.Type == "NetworkInterface"      ? route.value.Target : null
    }
  }
  tags = merge(var.Tags, {
    Name = "RtPublic${var.Name}"
  })
}

resource "aws_route_table" "rt_nat" {
  count  = length(var.Subnets.Nat) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  # Ruta por defecto a NAT GW
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ig_nat[0].id
  }
  # AdditionalRoutes en NAT
  dynamic "route" {
    for_each = flatten([
      for s in var.Subnets.Nat : lookup(s, "AdditionalRoutes", [])
    ])
    content {
      cidr_block = lookup(route.value, "Cidr", null)
      network_interface_id      = route.value.Type == "NetworkInterface"      ? route.value.Target : null
    }
  }
  tags = merge(var.Tags, {
    Name = "RtNat${var.Name}"
  })
}

resource "aws_route_table" "rt_private" {
  count  = length(var.Subnets.Private) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  dynamic "route" {
    for_each = flatten([
      for s in var.Subnets.Private : lookup(s, "AdditionalRoutes", [])
    ])
    content {
      cidr_block = lookup(route.value, "Cidr", null)
      network_interface_id      = route.value.Type == "NetworkInterface"      ? route.value.Target : null
    }
  }
  tags = merge(var.Tags, {
    Name = "RtPrivate${var.Name}"
  })
}

#################################
# Route table associations
##################################

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.subnet_public)
  subnet_id      = aws_subnet.subnet_public[count.index].id
  route_table_id = aws_route_table.rt_public[0].id
}

resource "aws_route_table_association" "nat" {
  count          = length(aws_subnet.subnet_nat)
  subnet_id      = aws_subnet.subnet_nat[count.index].id
  route_table_id = aws_route_table.rt_nat[0].id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.subnet_private)
  subnet_id      = aws_subnet.subnet_private[count.index].id
  route_table_id = aws_route_table.rt_private[0].id
}
