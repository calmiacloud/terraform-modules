##############################
# VPC Block
##############################

resource "aws_vpc" "vpc" {
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

resource "aws_internet_gateway" "ig_internet" {
  count = length(var.Subnets.Public) > 0 ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "igw-${var.name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

resource "aws_eip" "eip_ig_nat" {
  count  = length(var.Subnets.Nat) > 0 ? 1 : 0
  domain = "vpc"
  tags = {
    Name        = "eip-nat-${var.name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

resource "aws_nat_gateway" "ig_nat" {
  count         = length(var.Subnets.Nat) > 0 ? 1 : 0
  allocation_id = aws_eip.eip_ig_nat_main[0].id
  subnet_id     = aws_subnet.nat[data.aws_availability_zones.available.names[0]].id
  tags = {
    Name        = "nat-gateway-${var.name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

##################################
# Subnets Block
##################################

resource "aws_subnet" "public" {
  count                             = length(var.Subnets.Public)
  vpc_id                            = aws_vpc.vpc.id
  cidr_block                        = var.Subnets.Public[count.index].Cidr
  availability_zone                 = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch           = true
  assign_ipv6_address_on_creation   = var.Vpc.Ipv6Support
  tags = {
    Name        = "subnet-public-${var.Subnets.Public[count.index].Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

resource "aws_subnet" "private" {
  for_each = {
    for subnet in var.Subnets.Nat : "nat-${subnet.Name}" => merge(subnet, { type = "nat" })
    ...
    for subnet in var.Subnets.Private : "private-${subnet.Name}" => merge(subnet, { type = "private" })
  }

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value.Cidr
  availability_zone = element(data.aws_availability_zones.available.names, index(keys(aws_subnet.private), each.key))
  tags = {
    Name        = "${each.value.type}-${each.value.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

#################################
# Route Table Block
#################################

#################################
# Route Table Association Block
#################################
