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
  records = each.value.Records
  zone_id = var.Zone
}

##############################
# Waiter Block
##############################

resource "null_resource" "resource_main" {
  depends_on = [aws_route53_record.record]
  for_each = {
    for record in var.Records : "${record.Name}-${record.Type}" => record
  }
  triggers = {
    name   = each.value.Name
    type   = each.value.Type
    value  = join(",", each.value.Records) # en caso de múltiples valores
  }
  environment = {
    TF_ACTION = terraform.workspace == "destroy" ? "destroy" : "apply"
  }
  provisioner "local-exec" {
    command = "bash ${path.module}/src/checkrecord.sh ${self.triggers.name} ${self.triggers.type} ${self.triggers.value}"
  }
}