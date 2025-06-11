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

resource "null_resource" "dns_check" {
  for_each = {
    for record in var.Records : "${record.Name}-${record.Type}" => record
  }

  provisioner "local-exec" {
    when    = create
    command = "bash ${path.module}/src/checkrecords.sh ${var.Zone} ${each.value.Name} ${each.value.Type}"
  }

  depends_on = [aws_route53_record.record]
}