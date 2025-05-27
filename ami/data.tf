data "aws_region" "current" {}

data "aws_ami" "data_ami" {
  most_recent = true
  owners = ["self"]
  filter {
    name   = "name"
    values = ["${var.Tags.Project}${var.Tags.Stage}${var.Name}*"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  depends_on = [null_resource.resource_main]
}

