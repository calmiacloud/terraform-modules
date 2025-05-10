##############################
# Name
##############################

resource "random_string" "random_id" {
  length  = 6
  upper   = true
  lower   = true
  numeric = true
  special = false
}

#################################
# SSH Block
##################################

#resource "tls_private_key" "sshpair" {
#  algorithm = "RSA"
#  rsa_bits  = 4096
#}

resource "aws_key_pair" "keypair" {
  key_name   = "${var.Name}${random_string.random_id.result}"
  public_key = base64decode(var.PublicKeyB64)
  tags = {
    Name        = "vpc-${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}
