#################################
# SSH Block
##################################

resource "aws_key_pair" "keypair" {
  key_name   = "${var.Product}${var.Stage}${var.Name}"
  public_key = base64decode(var.PublicKeyB64)
  tags = merge(
    {
      Name = var.Name
    },
    var.tags
  )
}
