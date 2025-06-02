##############################
# VPC Block
##############################

resource "aws_vpc" "vpc" {
  cidr_block                     = var.Vpc.Cidr
  enable_dns_support             = true
  enable_dns_hostnames           = var.Vpc.DnsSupport
  assign_generated_ipv6_cidr_block = var.Vpc.Ipv6Support
  tags = merge(var.Tags, {
    Name = var.Name
  })
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
  tags = merge(
    {
      Name = "Public${var.Subnets.Public[count.index].Name}"
    },
    var.Tags
  )
}

resource "aws_subnet" "subnet_nat" {
  count                   = length(var.Subnets.Nat)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.Subnets.Nat[count.index].Cidr
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = false
  tags = merge(
    {
      Name = "Nat${var.Subnets.Nat[count.index].Name}"
    },
    var.Tags
  )
}


resource "aws_subnet" "subnet_private" {
  for_each = {
    for s in var.Subnets.Private : s.Name => s
  }
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value.Cidr
  availability_zone = element(data.aws_availability_zones.available.names, 0) # ajusta si tienes varias AZs
  tags = merge(
    {
      Name = "Private${each.value.Name}"
    },
    var.Tags
  )
}

##############################
# Gateways
##############################

resource "aws_internet_gateway" "ig_internet" {
  count  = length(var.Subnets.Public) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  tags = merge(var.Tags, {
    Name = var.Name
  })
}

resource "aws_eip" "eip_ig_nat" {
  count  = length(var.Subnets.Nat) > 0 ? 1 : 0
  domain = "vpc"
  tags = merge(var.Tags, {
    Name = var.Name
  })
}

resource "aws_nat_gateway" "ig_nat" {
  count         = length(var.Subnets.Nat) > 0 ? 1 : 0
  allocation_id = aws_eip.eip_ig_nat[0].id
  subnet_id     = aws_subnet.subnet_public[0].id
  tags = merge(var.Tags, {
    Name = var.Name
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
    Name = var.Name
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
    Name = var.Name
  })
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
  tags = merge(var.Tags, {
    Name = var.Name
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
  for_each       = aws_subnet.subnet_private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.rt_private[0].id
}
