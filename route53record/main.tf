##############################
# Route53 Block
##############################

resource "aws_route53_zone" "zone" {
  name = var.Domain
  dynamic "vpc" {
    for_each = var.Type == "Private" ? [var.Vpc] : []
    content {
      vpc_id = vpc.value
    }
  }
  tags = merge(var.Tags, {
    Name = "Route53Zone${var.Name}"
  })
}


resource "aws_route53_record" "record" {
  for_each = {
    for Record in var.Records : "${Record.Name}-${Record.Type}" => record
  }
  zone_id = var.Zone
  name    = each.value.Name
  type    = each.value.Type
  ttl     = each.value.Ttl
  records = each.value.Type == "MX" ? null : each.value.Records

  # MX records usan una estructura especial
  dynamic "mx" {
    for_each = each.value.Type == "MX" ? each.value.Records : []
    content {
      preference = mx.value.preference
      exchange   = mx.value.exchange
    }
  }
}
