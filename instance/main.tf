##############################
# Roles Block
##############################

resource "aws_iam_role" "role_ssm" {
  name = "${var.Tags.Project}${var.Tags.Stage}Instance${var.Name}"
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
  tags = merge(var.Tags, {
    Name = var.Name
  })
}

##############################
# Instanceprofile Block
##############################

resource "aws_iam_instance_profile" "instanceprofile_ssm" {
  name = "${var.Name}"
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
  tags = merge(var.Tags, {
    Name = var.Name
  })
  root_block_device {
    tags = merge(
      {
        Name = var.Name
      },
      var.Tags
    )
  }
}
