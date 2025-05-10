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
# Policies and Instance Profile
##############################

resource "aws_iam_policy" "policy_bucket" {
  name   = "PolicyBucketAmi${var.Name}${random_string.random_id.result}"
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
  name   = "RoleSsmAmi${var.Name}${random_string.random_id.result}"
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

resource "aws_iam_instance_profile" "instanceprofile_main" {
  name = "InstanceprofileAmi${var.Name}${random_string.random_id.result}"
  role = aws_iam_role.role_ssm.name
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
  component { component_arn = aws_imagebuilder_component.component_basicpackages.arn }
  #component { component_arn = "arn:aws:imagebuilder:eu-south-2:aws:component/aws-cli-version-2-linux/1.0.4/1" }
  component { component_arn = aws_imagebuilder_component.component_installansible.arn }
  component {
    component_arn = aws_imagebuilder_component.component_downloadplaybook.arn
    parameter {
      name  = "S3Bucket"
      value = aws_s3_bucket.bucket.bucket
    }
    parameter {
      name  = "S3Key"
      value = aws_s3_object.object.key
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

##############################
# Infrastructure Block
##############################

resource "aws_imagebuilder_infrastructure_configuration" "infra_main" {
  name                 = "AmiInfra${var.Name}${random_string.random_id.result}"
  instance_profile_name = aws_iam_instance_profile.instanceprofile_main.name
  instance_types       = [var.Instance.InstanceType]
  subnet_id            = var.Instance.Subnet
  security_group_ids   = [var.Instance.SecurityGroup]
  key_pair             = var.Instance.KeyPair
}

##############################
# Distribution Configuration
##############################

resource "aws_imagebuilder_distribution_configuration" "distribution_main" {
  name = "AmiDistribution${var.Name}${random_string.random_id.result}"
  distribution {
    region = data.aws_region.current.name
    ami_distribution_configuration {
      name        = "Ami${var.Name}${random_string.random_id.result}-{{ imagebuilder:buildDate }}"
      ami_tags = {
        Name        = var.Name
        Product     = var.Product
        Environment = var.Environment
      }
    }
  }
  tags = {
    Name        = var.Name
    Product     = var.Product
    Environment = var.Environment
  }
}

##############################
# Pipeline Block
##############################

resource "aws_imagebuilder_image_pipeline" "pipeline_main" {
  name                                = "AmiPipeline${var.Name}${random_string.random_id.result}"
  image_recipe_arn                    = aws_imagebuilder_image_recipe.recipe_main.arn
  infrastructure_configuration_arn    = aws_imagebuilder_infrastructure_configuration.infra_main.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.distribution_main.arn
  image_tests_configuration {
    image_tests_enabled = false
  }
  lifecycle {
    replace_triggered_by = [
      aws_imagebuilder_image_recipe.recipe_main
    ]
  }
}

# aws imagebuilder start-image-pipeline-execution --image-pipeline-arn $ARN