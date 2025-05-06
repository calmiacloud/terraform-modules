#################################
# SSH Block
##################################

resource "tls_private_key" "sshpair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "keypair" {
  key_name   = var.Name${var.random_id}
  public_key = tls_private_key.sshpair.public_key_openssh
  tags = {
    Name        = "vpc-${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}