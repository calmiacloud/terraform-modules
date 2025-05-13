#################################
# SSH Block
##################################

#resource "tls_private_key" "sshpair" {
#  algorithm = "RSA"
#  rsa_bits  = 4096
#}

resource "aws_key_pair" "keypair" {
  key_name   = "${var.Name}${var.Stage}"
  public_key = base64decode(var.PublicKeyB64)
  tags = {
    Name        = "vpc-${var.Name}"
    Product     = var.Product
    Stage       = var.Stage
  }
}
