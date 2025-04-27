##############################
# VPC Block
##############################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.dns_support
  enable_dns_support   = var.dns_support
  assign_generated_ipv6_cidr_block = var.ipv6_support
  tags = {
    Name = "vpc-main"
    Product = var.Product
    Environment = var.Environment
  }
}

##############################
# Internet Gateways
##############################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "igw-main"
    Product = var.Product
    Environment = var.Environment
  }
}

resource "aws_eip" "eip_ig_nat_main" {
  for_each = toset(data.aws_availability_zones.available.names)
  tags = {
    Name = "eip-nat-${each.key}"
    Product = var.Product
    Environment = var.Environment
  }
}

resource "aws_nat_gateway" "ig_nat_main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["eu-south-2a"].id
  tags = {
    Name = "nat-gateway-${each.key}"
    Product = var.Product
    Environment = var.Environment
  }
}

##################################
# Subnets Block
##################################

resource "aws_subnet" "public" {
  for_each                        = toset(data.aws_availability_zones.available.names)
  vpc_id                          = aws_vpc.this.id
  cidr_block                      = cidrsubnet(var.vpc_cidr, 2, index(data.aws_availability_zones.available.names, each.key))
  availability_zone               = each.key
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = var.ipv6_support
  tags = {
    Name = "igw-main"
    Product = var.Product
    Environment = var.Environment
  }
}

resource "aws_subnet" "subnet_privatenat" {
  for_each                          = toset(local.azs)
  vpc_id                            = aws_vpc.vpc_main.id
  cidr_block                        = cidrsubnet(var.ENV_AWS_VPC.PrivateNat, 2, index(local.azs, each.key))
  availability_zone                 = each.key
  assign_ipv6_address_on_creation   = true
  ipv6_cidr_block                   = cidrsubnet(aws_vpc.vpc_main.ipv6_cidr_block, 8, index(local.azs, each.key))
  tags = {
    Name = "private-with-nat-${each.key}"
  }
}

resource "aws_subnet" "subnet_private" {
  for_each          = toset(local.azs)
  vpc_id            = aws_vpc.vpc_main.id
  cidr_block        = cidrsubnet(var.ENV_AWS_VPC.Private, 2, index(local.azs, each.key))
  availability_zone = each.key
  tags = {
    Name = "private-no-nat-${each.key}"
  }
}

#################################
# Route Table Block
#################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.this.id
  }
  tags = {
    Name = "igw-main"
    Product = var.Product
    Environment = var.Environment
  }
}

resource "aws_route_table" "rt_privatenat" {
  vpc_id = aws_vpc.vpc_main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "private-with-nat-rt"
  }
}

resource "aws_route_table" "rt_private" {
  vpc_id = aws_vpc.vpc_main.id
  tags = {
    Name = "private-no-nat-rt"
  }
}

#################################
# Route Table Association Block
#################################

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "rtassoc_privatenat" {
  for_each       = aws_subnet.subnet_privatenat
  subnet_id      = each.value.id
  route_table_id = aws_route_table.rt_privatenat.id
}

resource "aws_route_table_association" "rtassoc_private" {
  for_each       = aws_subnet.subnet_private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.rt_private.id
}
