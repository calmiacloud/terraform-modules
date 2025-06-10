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




resource "null_resource" "resource_main" {
  for_each = {
    for record_key, record in var.Records :
    record_key => record
    if !var.ZonePrivate
  }
  provisioner "local-exec" {
    when    = create
    command = <<EOT
echo "Probando el registro DNS ${each.value.Name} (${each.value.Type})..."
aws route53 test-dns-answer \
  --hosted-zone-id ${var.Zone} \
  --record-name ${each.value.Name} \
  --record-type ${each.value.Type}
EOT
  }
  depends_on = [aws_route53_record.record]
}