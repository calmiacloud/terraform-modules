##############################
# VPC Block
##############################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-vpc"
    }
  )
}

##############################
# Internet Gateway
##############################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-igw"
    }
  )
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
  assign_ipv6_address_on_creation = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-subnet-public-${each.key}"
    }
  )
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

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rt-public"
    }
  )
}

#################################
# Route Table Association Block
#################################

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
