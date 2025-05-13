data "aws_region" "current" {}
/*
data "aws_ami" "data_ami" {
  most_recent = true
  owners = ["self"]
  filter {
    name   = "name"
    values = ["Ami${var.Name}${var.Stage}-*"]
  }
  depends_on = [null_resource.resource_main]
}*/