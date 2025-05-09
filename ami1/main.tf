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
  name     = "AmiComponentBasicPackages-${var.Name}-${random_string.random_id.result}"
  version  = "1.0.0"
  platform = "Linux"
  data = <<EOF
name: apt-basic-packages
schemaVersion: 1.0
phases:
  - name: build
    steps:
      - name: basic-packages
        action: ExecuteBash
        inputs:
          commands:
            - sudo apt-get install -y curl wget unzip software-properties-common
EOF
}

resource "aws_imagebuilder_component" "component_installansible" {
  name     = "AmiComponentAnsible-${var.Name}-${random_string.random_id.result}"
  version  = "1.0.0"
  platform = "Linux"
  data = <<EOF
name: apt-install-ansible
schemaVersion: 1.0
phases:
  - name: build
    steps:
      - name: Repo
        action: ExecuteBash
        inputs:
          commands:
            - add-apt-repository --yes --update ppa:ansible/ansible
            - apt-get update
      - name: Install
        action: ExecuteBash
        inputs:
          commands:
            - apt-get install -y ansible
EOF
}

resource "aws_imagebuilder_component" "component_downloadplaybook" {
  name     = "AmiComponentDownloadPlaybook-${var.Name}-${random_string.random_id.result}"
  version  = "1.0.0"
  platform = "Linux"
  data = <<EOF
name: "AmiComponentDownloadPlaybook${var.Name}${random_string.random_id.result}"
description: "Descarga el playbook de S3 a /tmp/playbook.yml"
schemaVersion: 1.0
phases:
  - name: build
    steps:
      - name: DownloadPlaybook
        action: S3Download
        maxAttempts: 3
        inputs:
          - source: "s3://${aws_s3_bucket.bucket.bucket}/${aws_s3_object.object.key}"
            destination: "/tmp/playbook.yml"
            overwrite: true
EOF
}

resource "aws_imagebuilder_component" "component_runplaybook" {
  name            = "AmiComponentRunPlaybook-${var.Name}-${random_string.random_id.result}"
  version         = "1.0.0"
  platform        = "Linux"
  data = <<-EOF
    name: run-playbook-with-extravars
    description: "Vuelca ExtraVars en /tmp/extravars.json y ejecuta el playbook"
    schemaVersion: '1.0'
    parameters:
      - name: ExtraVars
        type: string
        description: "JSON con las variables extra para el playbook"
    phases:
      - name: build
        steps:
          - name: WriteExtravars
            action: ExecuteBash
            inputs:
              commands:
                - |
                  cat << 'EOF_EXTRAVARS' > /tmp/extravars.json
                  {{ ExtraVars }}
                  EOF_EXTRAVARS

          - name: RunPlaybook
            action: ExecuteBash
            inputs:
              commands:
                - |
                  ansible-playbook -i localhost, \
                    -e "ansible_connection=local ansible_python_interpreter=/usr/bin/python3" \
                    -e @/tmp/extravars.json \
                    /tmp/playbook.yml
EOF
}

##############################
# Recipe Block
##############################

resource "aws_imagebuilder_image_recipe" "recipe_main" {
  name        = "AmiRecipe${var.Name}${random_string.random_id.result}"
  version     = "1.0.0"
  parent_image = var.Instance.ParentImage
 # block_device_mapping {
 #   device_name = "/dev/sda1"
 #   delete_on_termination = true
 #   ebs {
 #     volume_size = 8
 #     volume_type = "gp3"
 #   }
 # }
  component {
    component_arn = "arn:aws:imagebuilder:eu-south-2:aws:component/update-linux/1.0.2/1"
  }  
  component {
    component_arn = "arn:aws:imagebuilder:eu-south-2:aws:component/reboot-linux/1.0.1/1"
  }
  component {
    component_arn = aws_imagebuilder_component.component_basicpackages.arn
  }
  component {
    component_arn = "arn:aws:imagebuilder:eu-south-2:aws:component/aws-cli-version-2-linux/1.0.4/1"
  }
  component {
    component_arn = aws_imagebuilder_component.component_installansible.arn
  }
  component {
    component_arn = aws_imagebuilder_component.component_downloadplaybook.arn
  }
  component {
    component_arn = aws_imagebuilder_component.component_runplaybook.arn
    parameter {
      name  = "ExtraVars"
      value = jsonencode(var.ExtraVars)
    }
  }
  component {
    component_arn = "arn:aws:imagebuilder:eu-south-2:aws:component/reboot-linux/1.0.1/1"
  }
  tags = {
    Name        = "AmiRecipe${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}