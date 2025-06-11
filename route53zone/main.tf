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

##############################
# Waiter Block
##############################

resource "null_resource" "nullresource_main" {
  depends_on = [aws_route53_zone.zone]
  provisioner "local-exec" {
    when    = create
    command = "bash ${path.module}/src/checkzone.sh ${aws_route53_zone.zone.id}"
  }
}
