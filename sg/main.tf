##############################
# Security Group
##############################

resource "aws_security_group" "sg" {
  name        = "Sg${var.Name}${var.Stage}"
  vpc_id      = var.VpcId
  tags = {
    Name        = "Sg${var.Name}"
    Product     = var.Product
    Stage       = var.Stage
  }
}

##############################
# Security Group Rules
##############################

resource "aws_vpc_security_group_ingress_rule" "ingress" {
  for_each = { for idx, rule in var.Ingress : idx => rule }
  security_group_id = aws_security_group.sg.id
  from_port            = each.value.FromPort
  to_port                = each.value.ToPort
  ip_protocol          = each.value.Protocol
  cidr_ipv4        = each.value.Cidr
}

resource "aws_vpc_security_group_egress_rule" "egress" {
  for_each = { for idx, rule in var.Egress : idx => rule }
  security_group_id = aws_security_group.sg.id
  from_port = each.value.Protocol != "-1" ? each.value.FromPort : null
  to_port   = each.value.Protocol != "-1" ? each.value.ToPort   : null
  ip_protocol         = each.value.Protocol
  cidr_ipv4        = each.value.Cidr
}