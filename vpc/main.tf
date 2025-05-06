##############################
# VPC Block
##############################

resource "aws_vpc" "vpc" {
  cidr_block                     = var.Vpc.Cidr
  enable_dns_support             = var.Vpc.DnsSupport
  enable_dns_hostnames           = var.Vpc.DnsSupport
  assign_generated_ipv6_cidr_block = var.Vpc.Ipv6Support
  tags = {
    Name        = "Vpc-${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

##############################
# Internet Gateway
##############################

resource "aws_internet_gateway" "ig_internet" {
  count  = length(var.Subnets.Public) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "GwI-${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

resource "aws_eip" "eip_ig_nat" {
  count  = length(var.Subnets.Nat) > 0 ? 1 : 0
  domain = "vpc"
  tags = {
    Name        = "Eip-GwNat-${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

resource "aws_nat_gateway" "ig_nat" {
  count         = length(var.Subnets.Nat) > 0 ? 1 : 0
  allocation_id = aws_eip.eip_ig_nat[0].id
  subnet_id     = aws_subnet.subnet_public[0].id
  tags = {
    Name        = "GwNat-${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

##################################
# Subnets
##################################

resource "aws_subnet" "subnet_public" {
  count                             = length(var.Subnets.Public)
  vpc_id                            = aws_vpc.vpc.id
  cidr_block                        = var.Subnets.Public[count.index].Cidr
  availability_zone                 = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch           = true
  assign_ipv6_address_on_creation   = var.Vpc.Ipv6Support
  tags = {
    Name        = "SubnetPublic${var.Subnets.Public[count.index].Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

resource "aws_subnet" "subnet_private" {
  for_each = {
    for subnet in concat(
      [for s in var.Subnets.Nat : merge(s, { type = "nat", key = "Nat${s.Name}" })],
      [for s in var.Subnets.Private : merge(s, { type = "private", key = "Private${s.Name}" })]
    ) : subnet.key => subnet
  }
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value.Cidr
  availability_zone = element(data.aws_availability_zones.available.names, index(keys(aws_subnet.subnet_private), each.key))
  tags = {
    Name        = "Subnet${each.value.type}-${each.value.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

#################################
# Routes Block
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
      cidr_block                = lookup(route.value, "Cidr", null)
      network_interface_id      = route.value.Type == "NetworkInterface"     ? route.value.Target : null
    }
  }
  tags = {
    Name        = "RtPublic${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

resource "aws_route_table" "rt_nat" {
  count  = length(var.Subnets.Nat) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ig_nat[0].id
  }
  dynamic "route" {
    for_each = flatten([
      for s in var.Subnets.Public : lookup(s, "AdditionalRoutes", [])
    ])
    content {
      cidr_block                = lookup(route.value, "Cidr", null)
      network_interface_id      = route.value.Type == "NetworkInterface"     ? route.value.Target : null
    }
  }
  tags = {
    Name        = "RtNat${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

resource "aws_route_table" "rt_private" {
  count  = length(var.Subnets.Private) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  dynamic "route" {
    for_each = flatten([
      for s in var.Subnets.Private : lookup(s, "AdditionalRoutes", [])
    ])
    content {
      cidr_block           = lookup(route.value, "Cidr", null)
      network_interface_id = try(route.value.Target, null)
    }
  }
  tags = {
    Name        = "RtPrivate${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

#################################
# Routes Assoc Block
##################################

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.rt_public[0].id
}

resource "aws_route_table_association" "nat" {
  count          = length(aws_subnet.subnet_nat) > 0 ? 0 : 0
  subnet_id      = aws_subnet.subnet_nat[count.index].id
  route_table_id = aws_route_table.rt_nat[0].id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.subnet_private)
  subnet_id      = aws_subnet.subnet_private[count.index].id
  route_table_id = aws_route_table.rt_private[0].id
}