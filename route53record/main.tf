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
  depends_on = [aws_route53_record.record]
  provisioner "local-exec" {
    when = create
    command = <<EOT
echo "Comprobando si la zona ${var.Zone} es pública..."
IS_PRIVATE=$(aws route53 get-hosted-zone --id ${var.Zone} --query "HostedZone.Config.PrivateZone" --output text)

if [ "$IS_PRIVATE" = "true" ]; then
  echo "Zona privada detectada. No se realiza comprobación DNS."
  exit 0
fi

echo "Zona pública detectada. Probando el registro ${each.value.Name} (${each.value.Type})..."
aws route53 test-dns-answer \
  --hosted-zone-id ${var.Zone} \
  --record-name ${each.value.Name} \
  --record-type ${each.value.Type}
EOT
  }
}
