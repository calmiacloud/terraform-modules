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
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name        = "GwNat-${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

##################################
# Public Subnets
##################################

resource "aws_subnet" "public" {
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

##################################
# Private and NAT Subnets
##################################

resource "aws_subnet" "private" {
  for_each = {
    for subnet in concat(
      [for s in var.Subnets.Nat : merge(s, { type = "nat", key = "Nat${s.Name}" })],
      [for s in var.Subnets.Private : merge(s, { type = "private", key = "Private${s.Name}" })]
    ) : subnet.key => subnet
  }
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value.Cidr
  availability_zone = element(data.aws_availability_zones.available.names, index(keys(aws_subnet.private), each.key))
  tags = {
    Name        = "Subnet${each.value.type}-${each.value.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}
