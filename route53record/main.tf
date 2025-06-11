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
    when = create
    command = <<EOT
echo "Obteniendo información de la zona ${var.Zone}..."
ZONE_INFO=$(aws route53 get-hosted-zone --id ${var.Zone})
IS_PRIVATE=$(echo "$ZONE_INFO" | jq -r '.HostedZone.Config.PrivateZone')
ZONE_NAME=$(echo "$ZONE_INFO" | jq -r '.HostedZone.Name')

if [ "$IS_PRIVATE" = "true" ]; then
  echo "Zona privada detectada (${ZONE_NAME}). No se realiza comprobación DNS."
  exit 0
fi

# Asegura que no haya doble punto si ya viene como FQDN
RECORD_NAME="${each.value.Name}"
if [[ "$RECORD_NAME" != *"." ]]; then
  FQDN="${RECORD_NAME}.${ZONE_NAME}"
else
  FQDN="$RECORD_NAME"
fi

echo "Zona pública detectada. Probando el registro DNS ${FQDN} (${each.value.Type})..."
aws route53 test-dns-answer \
  --hosted-zone-id ${var.Zone} \
  --record-name "${FQDN}" \
  --record-type ${each.value.Type}
EOT
  }

  depends_on = [aws_route53_record.record]
}
d