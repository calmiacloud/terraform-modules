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
# Ssm Document
##############################

resource "aws_ssm_document" "ssmdocument_main" {
  name          = "SsmDocAmi${var.Name}${random_string.random_id.result}"
  document_type = "Automation"
  depends_on = [aws_s3_object.object]
  content = jsonencode({
    "schemaVersion": "0.3",
    "mainSteps": [
      {
        "name":"DescribeImage",
        "action":"aws:executeAwsApi",
        "nextStep":"DeleteAMI",
        "isEnd":false,
        "inputs":{
          "Service":"ec2",
          "Api":"DescribeImages",
          "Filters":[
            { "Name":"name", "Values": ["Ami${var.Name}${random_string.random_id.result}"]},
            { "Name":"state", "Values":["available"]}
          ]
        },
        "outputs":[ { "Name":"ImageId", "Selector":"$.Images[0].ImageId", "Type":"String" } ]
      },
      {
        "name": "DeleteAMI",
        "action": "aws:executeAwsApi",
        "nextStep": "LaunchInstance",
        "isCritical": false,
        "isEnd": false,
        "onFailure": "step:LaunchInstance",
        "inputs": {
          "Service": "ec2",
          "Api":     "DeleteImage",
          "ImageId": "{{ DescribeImage.Outputs.ImageId }}"
        }
      },
      {
        "name": "LaunchInstance",
        "action": "aws:runInstances",
        "nextStep": "TagInstance",
        "isEnd": false,
        "inputs": {
          "ImageId": "${var.Instance.ParentImage}",
          "InstanceType": "${var.Instance.InstanceType}",
          "SecurityGroupIds": ["${var.Instance.SecurityGroup}"],
          "SubnetId": "${var.Instance.Subnet}",
          "KeyName": "${var.Instance.KeyPair}",
          "IamInstanceProfileName": "${aws_iam_role.role_ssm.name}"
        }
      },
      {
        "name": "TagInstance",
        "action": "aws:createTags",
        "nextStep": "Update",
        "inputs": {
          "Tags": [
            { "Key": "Name", "Value": "InstanceSsmAmi${var.Name}${random_string.random_id.result}" },
            { "Key": "Product", "Value": var.Product },
            { "Key": "Environment", "Value": var.Environment },
          ],
          "ResourceIds": [ "{{ LaunchInstance.InstanceIds }}"]
        }
      },
      {
        "name": "Update",
        "action": "aws:runCommand",
        "nextStep": "BasicPackages",
        "onFailure": "step:TerminateInstance",
        "isEnd": false,
        "inputs": {
          "InstanceIds": ["{{ LaunchInstance.InstanceIds }}"],
          "DocumentName": "AWS-RunShellScript",
          "Parameters": {
            "commands": [
              "sudo DEBIAN_FRONTEND='noninteractive' apt-get update",
              "sudo DEBIAN_FRONTEND='noninteractive' apt-get upgrade -y"
            ]
          }
        }
      },
      {
        "name": "BasicPackages",
        "action": "aws:runCommand",
        "nextStep": "InstallAwsCli",
       "onFailure": "step:TerminateInstance",
        "isEnd": false,
        "inputs": {
          "InstanceIds": ["{{ LaunchInstance.InstanceIds }}"],
          "DocumentName": "AWS-RunShellScript",
          "Parameters": {
            "commands": [
              "sudo DEBIAN_FRONTEND='noninteractive' apt-get install curl wget unzip software-properties-common -y"
            ]
          }
        }
      },
      {
        "name": "InstallAwsCli",
        "action": "aws:runCommand",
        "nextStep": "InstallAnsible",
        "onFailure": "step:TerminateInstance",
        "isEnd": false,
        "inputs": {
          "InstanceIds": ["{{ LaunchInstance.InstanceIds }}"],
          "DocumentName": "AWS-RunShellScript",
          "Parameters": {
            "commands": [
              "curl 'https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip' -o '/tmp/awscliv2.zip'",
              "unzip /tmp/awscliv2.zip -d /tmp",
              "sudo DEBIAN_FRONTEND='noninteractive' /tmp/aws/install"
            ]
          }
        }
      },
      {
        "name": "InstallAnsible",
        "action": "aws:runCommand",
        "nextStep": "S3Object",
       "onFailure": "step:TerminateInstance",
        "isEnd": false,
        "inputs": {
          "InstanceIds": ["{{ LaunchInstance.InstanceIds }}"],
          "DocumentName": "AWS-RunShellScript",
          "Parameters": {
            "commands": [
              "sudo DEBIAN_FRONTEND='noninteractive' add-apt-repository --yes ppa:ansible/ansible",
              "sudo DEBIAN_FRONTEND='noninteractive' apt-get update -y",
              "sudo DEBIAN_FRONTEND='noninteractive' apt-get install -y ansible"
            ]
          }
        }
      },
      {
        "name": "S3Object",
        "action": "aws:runCommand",
        "nextStep": "RunPlaybook",
        "onFailure": "step:TerminateInstance",
        "isEnd": false,
        "inputs": {
          "InstanceIds": ["{{ LaunchInstance.InstanceIds }}"],
          "DocumentName": "AWS-RunShellScript",
          "Parameters": {
            "commands": [
              "aws s3 cp s3://${aws_s3_bucket.bucket.bucket}/${aws_s3_object.object.key} /tmp/playbook.yml"
            ]
          }
        }
      },
      {
        "name": "RunPlaybook",
        "action": "aws:runCommand",
        "nextStep": "CreateAmi",
        "onFailure": "step:TerminateInstance",
        "isEnd": false,
        "inputs": {
          "InstanceIds": ["{{ LaunchInstance.InstanceIds }}"],
          "DocumentName": "AWS-RunShellScript",
          "Parameters": {
            "commands": [
              "echo '${jsonencode(var.ExtraVars)}' > /tmp/extravars.json",
              "ansible-playbook -i localhost, -e 'ansible_connection=local ansible_python_interpreter=/usr/bin/python3' -e @/tmp/extravars.json /tmp/playbook.yml"
            ]
          }
        }
      },
      {
        "name": "CreateAmi",
        "action": "aws:createImage",
        "nextStep": "TagAMI",
        "isEnd": false,
        "inputs": {
          "InstanceId": "{{ LaunchInstance.InstanceIds }}",
          "ImageName": "Ami${var.Name}${random_string.random_id.result}"
        }
      },
      {
        "name": "TagAMI",
        "action": "aws:createTags",
        "nextStep": "TerminateInstance",
        "isEnd": false,
        "inputs": {
          "ResourceType": "EC2",
          "ResourceIds": [
            "{{ CreateAmi.ImageId }}"
          ],
          "Tags": [
            { "Key": "Name", "Value": "Ami${var.Name}${random_string.random_id.result}" },
            { "Key": "Product", "Value": var.Product },
            { "Key": "Environment", "Value": var.Environment },
          ],
        }
      },
      {
        "name": "TerminateInstance",
        "action": "aws:executeAwsApi",
        "isEnd": true,
        "inputs": {
          "Service": "ec2",
          "Api": "TerminateInstances",
          "InstanceIds": "{{ LaunchInstance.InstanceIds }}"
        }
      }
    ]
  })
  tags = {
    Name        = "SsmDocAmi${var.Name}"
    Product     = var.Product
    Environment = var.Environment
  }
}

# Run document
/*
resource "null_resource" "null_ssm_run" {
  triggers = {
    playbook_checksum = filemd5(var.Playbook)
    extravars_hash    = md5(jsonencode(var.ExtraVars))
  }
  depends_on = [aws_ssm_document.ssmdocument_main]
  provisioner "local-exec" {
    command = <<EOT
      AUTOMATION_ID=$(aws ssm start-automation-execution \
        --document-name ${aws_ssm_document.ssmdocument_main.name} \
        --query "AutomationExecutionId" \
        --output text)

      echo ""
      echo -e "\e[32m ==> AutomationExecutionId: $AUTOMATION_ID\e[0m"
      echo ""

      for i in $(seq 1 90); do
        WAIT_TIME=30
        AUTOMATION_STATUS=$(aws ssm get-automation-execution \
          --automation-execution-id "$AUTOMATION_ID" \
          --query "AutomationExecution.AutomationExecutionStatus" \
          --output text)
          
        echo ""
        echo -e "\e[33m ==> Automation Execution Status: $AUTOMATION_STATUS\e[0m"
        echo -e "\e[33m ==> Waiting $WAIT_TIME\e[0m"
        echo ""

        sleep $WAIT_TIME;

        if [ "$AUTOMATION_STATUS" = "Success" ]; then
          echo ""
          echo -e "\e[32m ==> Automation SUCCESS\e[0m"
          echo ""
          exit 0
        fi

        if [ "$AUTOMATION_STATUS" = "Failed" ] || [ "$AUTOMATION_STATUS" = "Cancelled" ]; then
          echo ""
          echo -e "\e[31m ==> Automation FAILED: $AUTOMATION_STATUS\e[0m"
          echo ""
          exit 1
        fi
      done

      echo ""
      echo -e "\e[31m ==> Automation TIMEOUT\e[0m"
      echo ""
      exit 1
    EOT
  }
}

data "aws_ami" "data_ami" {
  most_recent = true
  owners = ["self"]
  filter {
    name   = "name"
    values = ["Ami${var.Name}${random_string.random_id.result}"]
  }
  depends_on = [null_resource.null_ssm_run]
}
*/