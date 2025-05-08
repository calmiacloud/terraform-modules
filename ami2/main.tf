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
# RESTO
##############################

resource "aws_image_builder_image_recipe" "example_recipe" {
  name        = "example-recipe"
  description = "Example Image Recipe"
  parent_image = "ami-0abcdef1234567890"  # Imagen base
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 30  # Tamaño del disco
      volume_type = "gp2"
    }
  }

  components {
    component {
      component_arn = "arn:aws:imagebuilder:eu-south-2:aws:component/amazon-linux-2/1.0.0"
    }
    # Aquí puedes añadir más componentes si es necesario
  }
}

resource "aws_image_builder_infrastructure_configuration" "example_infrastructure" {
  name                = "example-infrastructure"
  instance_profile_name = "EC2InstanceProfile"  # Perfil de la instancia
  instance_type       = "t3.micro"  # Tipo de instancia
}

resource "aws_image_builder_image_pipeline" "example_pipeline" {
  name        = "example-pipeline"
  image_recipe_arn                    = aws_image_builder_image_recipe.example_recipe.arn
  infrastructure_configuration_arn     = aws_image_builder_infrastructure_configuration.example_infrastructure.arn
  status = "ENABLED"
  build {
    workflow {
      arn = "arn:aws:imagebuilder:eu-south-2:aws:workflow/build/build-image/1.0.2"
    }
  }
}

resource "aws_image_builder_image" "example_image" {
  image_recipe_arn                = aws_image_builder_image_recipe.example_recipe.arn
  infrastructure_configuration_arn = aws_image_builder_infrastructure_configuration.example_infrastructure.arn
  pipeline_arn                    = aws_image_builder_image_pipeline.example_pipeline.arn
}
