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

resource "aws_imagebuilder_component" "component_basicpackages" {
  name     = "AmiComponentBasicPackages${var.Name}${random_string.random_id.result}"
  version  = "1.0.0"
  platform = "Linux"
  data     = file("${path.module}/components/basic_packages.yml")
  tags = {
    Name        = "AmiComponentBasicPackages${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

resource "aws_imagebuilder_component" "component_installansible" {
  name     = "AmiComponentAnsible${var.Name}${random_string.random_id.result}"
  version  = "1.0.0"
  platform = "Linux"
  data     = file("${path.module}/components/install_ansible.yml")
  tags = {
    Name        = "AmiComponentAnsible${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

resource "aws_imagebuilder_component" "component_downloadplaybook" {
  name     = "AmiComponentDownloadPlaybook${var.Name}${random_string.random_id.result}"
  version  = "1.0.0"
  platform = "Linux"
  data     = file("${path.module}/components/download_playbook.yml")
  tags = {
    Name        = "AmiComponentDownloadPlaybook${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

resource "aws_imagebuilder_component" "component_runplaybook" {
  name             = "AmiComponentRunPlaybook${var.Name}${random_string.random_id.result}"
  version  = "1.0.0"
  platform = "Linux"
  data     = file("${path.module}/components/run_playbook.yml")
  tags = {
    Name        = "AmiComponentRunPlaybook${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

##############################
# Recipe Block
##############################

resource "aws_imagebuilder_image_recipe" "recipe_main" {
  name         = "AmiRecipe${var.Name}${random_string.random_id.result}"
  version      = "1.0.0"
  parent_image = var.Instance.ParentImage

  component { component_arn = "arn:aws:imagebuilder:eu-south-2:aws:component/update-linux/1.0.2/1" }
  component { component_arn = "arn:aws:imagebuilder:eu-south-2:aws:component/reboot-linux/1.0.1/1" }
  component { component_arn = aws_imagebuilder_component.component_basicpackages.arn }
  component { component_arn = "arn:aws:imagebuilder:eu-south-2:aws:component/aws-cli-version-2-linux/1.0.4/1" }
  component { component_arn = aws_imagebuilder_component.component_installansible.arn }
  component {
    component_arn = aws_imagebuilder_component.component_downloadplaybook.arn
    parameter {
      name  = "S3Bucket"
      value = local.s3_bucket
    }
    parameter {
      name  = "S3Key"
      value = local.s3_key
    }
  }
  component {
    component_arn = aws_imagebuilder_component.component_runplaybook.arn
    parameter {
      name  = "ExtraVars"
      value = jsonencode(var.ExtraVars)
    }
  }
  tags = {
    Name        = "AmiRecipe${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}
