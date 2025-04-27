resource "aws_security_group" "this" {
  name        = var.name
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = { for i, rule in var.ingress_rules : i => rule }
  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol
  cidr_ipv4         = each.value.cidr_ipv4
  tags = merge(
    var.rule_tags,
    {
      Name = each.value.name
    }
  )
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = { for i, rule in var.egress_rules : i => rule }
  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol
  cidr_ipv4         = each.value.cidr_ipv4
  tags = merge(
    var.rule_tags,
    {
      Name = each.value.name
    }
  )
}
