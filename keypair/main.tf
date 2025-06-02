#################################
# SSH Block
##################################

resource "aws_key_pair" "keypair" {
  key_name   = "Keypair${var.Name}"
  public_key = base64decode(var.PublicKeyB64)
  tags = merge(var.Tags, {
    Name = var.Name
  })
}
