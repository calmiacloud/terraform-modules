##############################
# Identity Block
##############################

resource "aws_ses_domain_identity" "identity" {
  domain = var.Domain
}