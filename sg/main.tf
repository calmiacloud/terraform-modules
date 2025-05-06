##############################
# Name
##############################

resource "random_string" "random_id" {
  length  = 6
  upper   = true
  lower   = true
  number  = true
  special = false
}

##############################
# Security Group
##############################

resource "aws_security_group" "sg" {
  name        = "Sg${var.Name}${random_string.random_id.result}"
  vpc_id      = var.VpcId
  tags = {
    Name        = "Sg${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

##############################
# Security Group Rules
##############################

resource "aws_vpc_security_group_ingress_rule" "ingress" {
  for_each = { for idx, rule in var.Ingress : idx => rule }
  security_group_id = aws_security_group.sg.id
  FromPort         = each.value.FromPort
  ToPort           = each.value.ToPort
  protocol          = each.value.protocol
  cidr_ipv4        = each.value.Cidr
}

resource "aws_vpc_security_group_egress_rule" "egress" {
  for_each = { for idx, rule in var.Egress : idx => rule }
  security_group_id = aws_security_group.sg.id
  FromPort         = each.value.FromPort
  ToPort           = each.value.ToPort
  protocol         = each.value.protocol
  cidr_ipv4        = each.value.Cidr
}