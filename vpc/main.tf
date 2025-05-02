##############################
# VPC Block
##############################

resource "aws_vpc" "this" {
  cidr_block                     = var.Vpc.VpcCidr
  enable_dns_support             = var.Vpc.DnsSupport
  enable_dns_hostnames           = var.Vpc.DnsSupport
  assign_generated_ipv6_cidr_block = var.Vpc.Ipv6Support
  tags = {
    Name        = "vpc-${var.name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

##############################
# Internet Gateways
##############################

resource "aws_internet_gateway" "this" {
  count = length(var.Subnets.Public) > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags = {
    Name        = "igw-${var.name}"
    Product     = var.Product
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
  count = length(var.Subnets.Public)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.Subnets.Public[count.index].Cidr
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = var.Subnets.Public[count.index].Internet
  assign_ipv6_address_on_creation = var.Vpc.Ipv6Support
  tags = {
    Name        = "public-${var.Subnets.Public[count.index].Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

resource "aws_subnet" "private" {
  count = length(var.Subnets.Private)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.Subnets.Private[count.index].Cidr
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name        = "private-${var.Subnets.Private[count.index].Name}"
    Product     = var.Product
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
