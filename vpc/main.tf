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
# Internet Gateway
##############################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "igw-main"
    Product = var.Product
    Environment = var.Environment
  }
}

##################################
# Subnets Block
##################################

resource "aws_subnet" "public" {
  for_each = toset(data.aws_availability_zones.available.names)
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

#################################
# Route Table Association Block
#################################

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
