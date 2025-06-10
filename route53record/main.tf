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
  records = each.value.Values   # aquí apuntamos a Values
  zone_id = var.Zone
}


##############################
# Waiter Block
##############################

resource "null_resource" "wait_record" {
  for_each = aws_route53_record.record
  depends_on = [
    aws_route53_record.record
  ]
  triggers = {
    name     = each.value.name
    type     = each.value.type
    # join con espacio si es TXT, con coma en otro caso
    expected = each.value.type == "TXT"
      ? join(" ", each.value.records)
      : join(",", each.value.records)
    zone     = var.Zone
  }
  provisioner "local-exec" {
    environment = {
      TF_ACTION = terraform.workspace == "destroy" ? "destroy" : "apply"
    }
    command = [
      "bash",
      "${path.module}/src/checkrecord.sh",
      each.value.name,
      each.value.type,
      each.value.expected,
      var.Zone,
    ]
  }
}
