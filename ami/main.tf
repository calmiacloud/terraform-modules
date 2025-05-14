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
# Bucket
##############################

resource "aws_s3_bucket" "bucket" {
  bucket        = lower("amibuilder${var.Name}${random_password.random_id.result}")
  force_destroy = true
  lifecycle {
    precondition {
      condition     = contains(fileset(var.Source, "**/*"), "main.yml")
      error_message = "main.yml not found in ${var.Source}"
    }
  }
  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
}

resource "aws_s3_object" "objects" {
  for_each = { for file in fileset(var.Source, "**/*") : file => file }
  bucket = aws_s3_bucket.bucket.bucket
  key    = "playbook/${each.key}"
  source = "${var.Source}/${each.key}"
  etag   = filemd5("${var.Source}/${each.key}")
}

##############################
# Policies and Instance Profile
##############################

resource "aws_iam_policy" "policy_bucket" {
  name   = "Amibuilder${var.Name}"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement: [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:HeadObject"
        ],
        Resource = "${aws_s3_bucket.bucket.arn}/playbook/*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket"
        ],
        Resource = aws_s3_bucket.bucket.arn
      }
    ]
  })

  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
}

resource "aws_iam_role_policy" "policy_imagebuilder" {
  name = "Amibuilder${var.Name}"
  role = aws_iam_role.role_ssm.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "imagebuilder:GetComponent",
          "imagebuilder:GetComponentPolicy",
          "imagebuilder:GetImageRecipe",
          "imagebuilder:GetImageRecipePolicy",
          "imagebuilder:GetInfrastructureConfiguration",
          "imagebuilder:GetDistributionConfiguration",
          "imagebuilder:GetImage"
        ]
        Resource = [
          aws_imagebuilder_component.component_basicpackages.arn,
          aws_imagebuilder_component.component_installansible.arn,
          aws_imagebuilder_component.component_downloadplaybook.arn,
          aws_imagebuilder_component.component_runplaybookreboot.arn,
          aws_imagebuilder_image_recipe.recipe_main.arn,
          aws_imagebuilder_infrastructure_configuration.infra_main.arn,
          aws_imagebuilder_distribution_configuration.distribution_main.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "role_ssm" {
  name = "Amibuilder${var.Name}"
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
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
}

resource "aws_iam_instance_profile" "instanceprofile_main" {
  name = "Amibuilder${var.Name}"
  role = aws_iam_role.role_ssm.name
}

##############################
# Components Block
##############################

resource "aws_imagebuilder_component" "component_basicpackages" {
  name = "BasicPackages${var.Name}"
  version  = "1.0.0"
  platform = "Linux"
  data     = file("${path.module}/src/components/basic_packages.yml")
  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
}

resource "aws_imagebuilder_component" "component_installansible" {
  name = "InstallAnsible${var.Name}"
  version  = "1.0.0"
  platform = "Linux"
  data     = file("${path.module}/src/components/install_ansible.yml")
  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
}

resource "aws_imagebuilder_component" "component_downloadplaybook" {
  name = "DownloadPlaybook${var.Name}"
  version  = "1.0.0"
  platform = "Linux"
  data     = file("${path.module}/src/components/download_playbook.yml")
  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
}

resource "aws_imagebuilder_component" "component_runplaybookreboot" {
  name = "RunPlaybook${var.Name}"
  version  = "1.0.0"
  platform = "Linux"
  data     = file("${path.module}/src/components/run_playbook_reboot.yml")
  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
}

##############################
# Recipe Block
##############################

resource "aws_imagebuilder_image_recipe" "recipe_main" {
  name = "${var.Name}"
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
      name  = "S3Prefix"
      value = "playbook"
    }
  }
  component {
    component_arn = aws_imagebuilder_component.component_runplaybookreboot.arn
    parameter {
      name  = "ExtraVars"
      value = jsonencode(var.ExtraVars)
    }
    parameter {
      name  = "PlaybookPath"
      value = "/tmp/playbook/main.yml"
    }
  }
  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
}

##############################
# Infrastructure Block
##############################

resource "aws_imagebuilder_infrastructure_configuration" "infra_main" {
  name = "${var.Name}"
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
  name = "${var.Name}"
  distribution {
    region = data.aws_region.current.name
    ami_distribution_configuration {
      name        = "${var.Name}{{ imagebuilder:buildDate }}"
      ami_tags = {
        Name        = var.Name
        Product     = var.Product
        Stage       = var.Stage
      }
    }
  }
  tags = {
    Name        = var.Name
    Product     = var.Product
    Stage       = var.Stage
  }
}

##############################
# Pipeline Block
##############################

resource "aws_imagebuilder_image_pipeline" "pipeline_main" {
  name                             = "${var.Name}"
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

##############################
# Trigger Block
##############################

resource "null_resource" "resource_main" {
  triggers = {
    playbook_md5 = sha256(join("", [
      for file in fileset(var.Source, "**/*") :
      filemd5("${var.Source}/${file}")
    ]))
    extra_vars_sha256 = sha256(jsonencode(var.ExtraVars))
  }
  depends_on = [
    aws_imagebuilder_image_pipeline.pipeline_main
  ]
  provisioner "local-exec" {
    command = "bash ${path.module}/src/runpipeline.sh ${aws_imagebuilder_image_pipeline.pipeline_main.arn} ${var.Name}"
  }
}