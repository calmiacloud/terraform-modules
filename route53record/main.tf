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
  for_each = {
    for record in var.Records :
    "${record.Name}-${record.Type}" => record
  }
  depends_on = [
    aws_route53_record.record[each.key]
  ]
  triggers = {
    name  = each.value.Name
    type  = each.value.Type
    value = each.value.Type == "TXT"
      ? join(" ", each.value.Values)
      : join(",", each.value.Values)
    zone  = var.Zone
  }
  provisioner "local-exec" {
    environment = {
      TF_ACTION = terraform.workspace == "destroy" ? "destroy" : "apply"
    }
    command = "bash ${path.module}/src/checkrecord.sh ${self.triggers.name} ${self.triggers.type} ${self.triggers.value} ${self.triggers.zone}"
  }
}
