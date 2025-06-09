##############################
# Identity Block
##############################

resource "aws_ses_domain_identity" "identity" {
  email = var.Domain
}