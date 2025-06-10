##############################
# Route53 Block
##############################

resource "aws_route53_record" "record" {
  for_each = {
    for record in var.Records : "${record.Name}-${record.Type}" => record
  }
  name    = each.value.Name
  type    = each.value.Type
  ttl     = each.value.Ttl
  records = each.value.Values
  zone_id = var.Zone
}

##############################
# Waiter Block
##############################

resource "null_resource" "check_route53_record" {
  for_each = aws_route53_record.record
  triggers = {
    record_name   = each.value.name
    record_type   = each.value.type
    record_values = join(",", each.value.records)
    zone_id       = var.Zone
  }
  depends_on = [
    aws_route53_record.record
  ]
  provisioner "local-exec" {
    command     = "bash \"${path.module}/src/checkrecord.sh\" \"${var.Zone}\" \"${each.value.name}\" \"${each.value.type}\""
  }
}
