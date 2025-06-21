##############################
# VPC Block
##############################

resource "aws_vpc" "vpc" {
  cidr_block                     = var.Cidr
  enable_dns_support             = true
  enable_dns_hostnames           = true
  assign_generated_ipv6_cidr_block = var.Ipv6Support
  tags = merge(var.Tags, {
    Name = "Vpc${var.Name}"
  })
}

##############################
# Subnets
##############################

resource "aws_subnet" "subnet_public" {
  count = length(flatten([for _, cidrs in var.Subnets.Public : cidrs]))
  vpc_id     = aws_vpc.vpc.id
  cidr_block = flatten([for _, cidrs in var.Subnets.Public : cidrs])[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  ipv6_cidr_block = var.Ipv6Support ? cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, count.index) : null
  assign_ipv6_address_on_creation = var.Ipv6Support ? true : null
  tags = merge(
    {
      Name = "SubnetPublic${flatten([for _, cidrs in var.Subnets.Public : cidrs])[count.index]}Az${count.index}"
    },
    var.Tags
  )
}

resource "aws_subnet" "subnet_nat" {
  count = length(flatten([for _, cidrs in lookup(var.Subnets, "Nat", {}) : cidrs]))
  vpc_id     = aws_vpc.vpc.id
  cidr_block = flatten([for _, cidrs in var.Subnets.Nat : cidrs])[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = false
  tags = merge(
    {
      Name = "SubnetNat${flatten([for _, cidrs in var.Subnets.Nat : cidrs])[count.index]}Az${count.index}"
    },
    var.Tags
  )
}

resource "aws_subnet" "subnet_private" {
  count = length(flatten([for _, cidrs in lookup(var.Subnets, "Private", {}) : cidrs]))
  vpc_id     = aws_vpc.vpc.id
  cidr_block = flatten([for _, cidrs in var.Subnets.Private : cidrs])[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = merge(
    {
      Name = "SubnetPrivate${flatten([for _, cidrs in var.Subnets.Private : cidrs])[count.index]}Az${count.index}"
    },
    var.Tags
  )
}

##############################
# Gateways
##############################

resource "aws_internet_gateway" "ig_internet" {
  count  = length(flatten([for _, cidrs in var.Subnets.Public : cidrs])) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  tags = merge(var.Tags, {
    Name = "Ig${var.Name}"
  })
}

resource "aws_eip" "eip_ig_nat" {
  count  = length(flatten([for _, cidrs in lookup(var.Subnets, "Nat", {}) : cidrs])) > 0 ? 1 : 0
  domain = "vpc"
  tags = merge(var.Tags, {
    Name = "EipIgn${var.Name}"
  })
}

resource "aws_instance" "nat" {
  ami                    = data.aws_ami.nat.id
  instance_type          = "t4g.nano"
  subnet_id              = aws_subnet.subnet_public[0].id
  associate_public_ip_address = false
  source_dest_check      = false

  # Configurar forwarding e iptables
  user_data = <<-EOF
    #!/bin/bash
    # Habilita forwarding IPv4
    sysctl -w net.ipv4.ip_forward=1
    # Instala iptables y configura masquerading
    yum install -y iptables-services
    iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE
    # Persiste reglas
    service iptables save
  EOF

  tags = merge(var.Tags, {
    Name = "Ign${var.Name}"
  })
}

resource "aws_eip_association" "nat" {
  instance_id   = aws_instance.nat.id
  allocation_id = aws_eip.nat.id
}

#################################
# Route tables
##################################

resource "aws_route_table" "rt_public" {
  count  = length(flatten([for _, cidrs in var.Subnets.Public : cidrs])) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig_internet[0].id
  }
  dynamic "route" {
    for_each = var.Ipv6Support ? [1] : []
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
  count  = length(flatten([for _, cidrs in lookup(var.Subnets, "Nat", {}) : cidrs])) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    instance_id = aws_instance.nat.id
  }
  tags = merge(var.Tags, {
    Name = "RtNat${var.Name}"
  })
}

resource "aws_route_table" "rt_private" {
  count  = length(flatten([for _, cidrs in lookup(var.Subnets, "Private", {}) : cidrs])) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  tags = merge(var.Tags, {
    Name = "RtPrivate${var.Name}"
  })
}

#################################
# Route table associations
##################################

resource "aws_route_table_association" "public" {
  count          = length(flatten([for _, cidrs in var.Subnets.Public : cidrs]))
  subnet_id      = aws_subnet.subnet_public[count.index].id
  route_table_id = aws_route_table.rt_public[0].id
}

resource "aws_route_table_association" "nat" {
  count          = length(flatten([for _, cidrs in lookup(var.Subnets, "Nat", {}) : cidrs]))
  subnet_id      = aws_subnet.subnet_nat[count.index].id
  route_table_id = aws_route_table.rt_nat[0].id
}

resource "aws_route_table_association" "private" {
  count          = length(flatten([for _, cidrs in lookup(var.Subnets, "Private", {}) : cidrs]))
  subnet_id      = aws_subnet.subnet_private[count.index].id
  route_table_id = aws_route_table.rt_private[0].id
}