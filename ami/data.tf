data "aws_region" "current" {}

#data "aws_ami" "data_ami" {
#  most_recent = true
#  owners = ["self"]
#  filter {
#    name   = "name"
#    values = ["${var.Product}${var.Stage}${var.Name}*"]
#  }
#  depends_on = [null_resource.resource_main]
#}