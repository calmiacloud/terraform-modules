#################################
# Random String Block
##################################

resource "random_password" "random_id" {
  length           = 6
  upper            = false
  lower            = true
  numeric          = true
  special          = false
}

##############################
# VPC Block
##############################

resource "aws_vpc" "vpc" {
  cidr_block                     = var.Vpc.Cidr
  enable_dns_support             = true
  enable_dns_hostnames           = var.Vpc.DnsSupport
  assign_generated_ipv6_cidr_block = var.Vpc.Ipv6Support
  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
}

##############################
# Subnets
##############################

resource "aws_subnet" "subnet_public" {
  count                   = length(var.Subnets.Public)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.Subnets.Public[count.index].Cidr
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  ipv6_cidr_block = var.Vpc.Ipv6Support ? cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, count.index) : null
  assign_ipv6_address_on_creation = var.Vpc.Ipv6Support ? true : null
  tags = {
    Name        = var.Subnets.Public[count.index].Name
    Product     = var.Product
    Stage       = var.Stage
  }
}

resource "aws_subnet" "subnet_nat" {
  count                   = length(var.Subnets.Nat)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.Subnets.Nat[count.index].Cidr
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = false
  tags = {
    Name        = var.Subnets.Nat[count.index].Name
    Product     = var.Product
    Stage       = var.Stage
  }
}

resource "aws_subnet" "subnet_private" {
  for_each = {
    for s in var.Subnets.Private : s.Name => s
  }
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value.Cidr
  availability_zone = element(data.aws_availability_zones.available.names, 0) # ajusta si tienes varias AZs
  tags = {
    Name        = each.value.Name
    Product     = var.Product
    Stage       = var.Stage
  }
}

##############################
# Gateways
##############################

resource "aws_internet_gateway" "ig_internet" {
  count  = length(var.Subnets.Public) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
}

resource "aws_eip" "eip_ig_nat" {
  count  = length(var.Subnets.Nat) > 0 ? 1 : 0
  domain = "vpc"
  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
}

resource "aws_nat_gateway" "ig_nat" {
  count         = length(var.Subnets.Nat) > 0 ? 1 : 0
  allocation_id = aws_eip.eip_ig_nat[0].id
  subnet_id     = aws_subnet.subnet_public[0].id
  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
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
  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
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
  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
}

# 3) Privada
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
  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
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
  subnet_id      = aws_subnet.subnet_private[values(aws_subnet.subnet_private)[count.index].id]
  route_table_id = aws_route_table.rt_private[0].id
}
