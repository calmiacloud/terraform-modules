##############################
# VPC Block
##############################

resource "aws_route53_zone" "zone" {
  name = var.domain
  dynamic "vpc" {
    for_each = var.is_private ? var.vpc_ids : []
    content {
      vpc_id = vpc.value
    }
  }
  private_zone = var.is_private
  tags = merge(var.Tags, {
    Name = "Royte53Zone${var.Name}"
  })
}

