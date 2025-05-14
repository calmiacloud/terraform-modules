#################################
# Random String Block
##################################

resource "random_password" "random_id" {
  length           = 6
  upper            = false
  lower            = true
  numeric          = true
  special          = false
}

#################################
# SSH Block
##################################

resource "aws_key_pair" "keypair" {
  key_name   = "${var.Name}${random_password.random_id.result}"
  public_key = base64decode(var.PublicKeyB64)
  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
}
