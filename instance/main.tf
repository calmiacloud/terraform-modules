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

##############################
# Roles Block
##############################

resource "aws_iam_role" "role_ssm" {
  name = "${var.Name}${random_password.random_id.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
}

##############################
# Instanceprofile Block
##############################

resource "aws_iam_instance_profile" "instanceprofile_ssm" {
  name = "${var.Name}${random_password.random_id.result}"
  role = aws_iam_role.role_ssm.name
}

##############################
# Instance Block
##############################

resource "aws_instance" "instance" {
  ami                         = var.Image
  instance_type               = var.InstanceType
  subnet_id                   = var.Subnet
  vpc_security_group_ids      = [var.SecurityGroup]
  key_name                    = var.KeyPair
  iam_instance_profile        = aws_iam_instance_profile.instanceprofile_ssm.name
  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
  root_block_device {
    tags = {
      Name        = var.Name
      Product     = var.Product
      Stage       = var.Stage
    }
  }
}
