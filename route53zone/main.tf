##############################
# VPC Block
##############################

resource "aws_route53_zone" "zone" {
  name = var.domain
  dynamic "vpc" {
    for_each = var.Type == "Private" ? [var.Vpc] : []
    content {
      vpc_id = vpc.value
    }
  }
  private_zone = var.Type == "Private"
  tags = merge(var.Tags, {
    Name = "Route53Zone${var.Name}"
  })
}

