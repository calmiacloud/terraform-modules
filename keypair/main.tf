#################################
# SSH Block
##################################

resource "aws_key_pair" "keypair" {
  key_name   = var.Name
  public_key = base64decode(var.PublicKeyB64)
  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
}
