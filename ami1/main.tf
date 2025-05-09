##############################
# Name
##############################

resource "random_string" "random_id" {
  length  = 6
  upper   = true
  lower   = true
  numeric = true
  special = false
}

##############################
# Bucket
##############################

resource "aws_s3_bucket" "bucket" {
  bucket = lower("BucketAmi${var.Name}${random_string.random_id.result}")
  force_destroy = true
  tags = {
    Name        = "BucketAmi${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

resource "aws_s3_object" "object" {
  bucket = aws_s3_bucket.bucket.bucket
  key    = "playbook.yml"
  source = var.Playbook
  etag   = filemd5(var.Playbook)
  force_destroy = true
}

##############################
# Policies
##############################

resource "aws_iam_policy" "policy_bucket" {
  name   = "PolicyBucketAmi${random_string.random_id.result}"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement: [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:HeadObject"
        ],
        Resource = "${aws_s3_bucket.bucket.arn}/*"
      }
    ]
  })
  tags = {
    Name        = "PolicyBucketAmi${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

resource "aws_iam_role" "role_ssm" {
  name   = "RoleSsmAmi${random_string.random_id.result}"
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
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    aws_iam_policy.policy_bucket.arn,
  ]
  tags = {
    Name        = "PolicySsmAmi${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

##############################
# Components Block
##############################

resource "aws_image_builder_component" "component_basicpackages" {
  name        = "AmiComponentBasicPackages${var.Name}${random_string.random_id.result}"
  version     = "1.0.0"
  platform = "Ubuntu"
  inline = <<EOF
    name: "CustomComponent"
    version: "1.0.0"
    phases:
    build:
        commands:
        - name: "InstallPackages"
            command: "sudo apt-get install curl wget unzip software-properties-common -y"
    EOF
}

resource "aws_image_builder_component" "component_ansible" {
  name        = "AmiComponentAnsible${var.Name}${random_string.random_id.result}"
  version     = "1.0.0"
  platform = "Ubuntu"
  inline = <<EOF
    name: "CustomComponent"
    version: "1.0.0"
    phases:
    build:
        commands:
        - name: "Enable Repo"
            command: "sudo add-apt-repository --yes ppa:ansible/ansible"
        - name: "InstallPackages"
            command: "sudo apt-get update -y"
        - name: "InstallPackages"
            command: "sudo apt-get install -y ansible"
    EOF
}

resource "aws_image_builder_component" "component_downloadplaybook" {
  name        = "AmiComponentDownloadPlaybook${var.Name}${random_string.random_id.result}"
  version     = "1.0.0"
  platform = "Ubuntu"
  inline = <<EOF
    name: "CustomComponent"
    version: "1.0.0"
    phases:
    build:
        commands:
        - name: "DownloadPlaybook"
            action: S3Download
            inputs:
            - source: "s3://${aws_s3_bucket.bucket.bucket}/${aws_s3_object.object.key}"
                destination: "/tmp/playbook.yml"
    EOF
}

##############################
# Recipe Block
##############################

resource "aws_imagebuilder_image_recipe" "recipe_main" {
  name        = "AmiRecipe${var.Name}${random_string.random_id.result}"
  version     = "1.0.0"
  parent_image = var.Instance.ParentImage
  block_device_mapping {
    device_name = "/dev/sda1"
    delete_on_termination = true
    ebs {
      volume_size = 8
      volume_type = "gp3"
    }
  }
  components {
    component_arn = "arn:aws:imagebuilder:eu-south-2:aws:component/update-linux/1.0.2/1"
  }  
  components {
    component_arn = "arn:aws:imagebuilder:eu-south-2:aws:component/reboot-linux/1.0.1/1"
  }
  components {
    component_arn = aws_image_builder_component.component_basicpackages.arn
  }
  components {
    component_arn = aws_image_builder_component.component_ansible.arn
  }
  components {
    component_arn = "arn:aws:imagebuilder:eu-south-2:aws:component/aws-cli-version-2-linux/1.0.4/1"
  }
  components {
    component_arn = aws_image_builder_component.component_downloadplaybook.arn
  }
  tags = {
    Name        = "AmiRecipe${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}