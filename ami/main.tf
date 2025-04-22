# Bucket

resource "aws_s3_bucket" "bucket" {
  bucket = "${var.platform}-${var.stage}-bucket-ami-${var.name}"
  force_destroy = true
}

resource "aws_s3_object" "bucketobject" {
  bucket = aws_s3_bucket.bucket.bucket
  key    = "playbook.yml"
  source = var.playbook
  etag   = filemd5(var.playbook)
  force_destroy = true
}

# Attach Policy

resource "aws_iam_policy" "policy_s3_playbook" {
  name        = "${var.platform}-${var.stage}-policy-bucket-ami-${var.name}"
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
}

resource "aws_iam_role_policy_attachment" "policyattach_role_ec2ssm_rule02" {
  role       = aws_iam_role.role_ec2ssm.name
  policy_arn = aws_iam_policy.policy_s3_ec2ssm.arn
}

resource "aws_iam_instance_profile" "instanceprofile_ec2ssm" {
  name = "${var.platform}-${var.stage}-instanceprofile-ec2ssm-${var.name}"
  role = aws_iam_role.role_ec2ssm.name
}

# SSM Document

resource "aws_ssm_document" "ssmdocument_main" {
  name          = "${var.platform}-${var.stage}-ssmdocument-${var.name}"
  document_type = "Automation"
  depends_on = [aws_s3_object.bucketobject]
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
            { "Name":"name", "Values":["${var.platform}-${var.stage}-ami-${var.name}"]},
            { "Name":"state", "Values":["available"]}
          ]
        },
        "outputs":[ { "Name":"ImageId", "Selector":"$.Images[0].ImageId", "Type":"String" } ]
      },
      {
         "name":"DeleteAMI",
         "action":"aws:deleteImage",
         "nextStep":"LaunchInstance",
         "isCritical": false,
         "isEnd":false,
         "onFailure":"step:LaunchInstance",
         "inputs":{ "ImageId":"{{ DescribeImage.ImageId }}"}
      },
      {
        "name": "LaunchInstance",
        "action": "aws:runInstances",
        "nextStep": "TagInstance",
        "isEnd": false,
        "inputs": {
          "ImageId": "${var.instance.image_id}",
          "InstanceType": "${var.instance.instance_type}",
          "SecurityGroupIds": ["${var.instance.security_group}"],
          "SubnetId": "${var.instance.subnet}",
          "KeyName": "${var.instance.keypair}",
          "IamInstanceProfileName": "${var.instance.instanceprofile}"
        }
      },
      {
        "name": "TagInstance",
        "action": "aws:createTags",
        "nextStep": "Update",
        "inputs": {
          "Tags": [{ "Key": "Name", "Value": "${var.platform}-${var.stage}-ec2instance-ssmdocument-${var.name}" }],
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
              "aws s3 cp s3://${aws_s3_bucket.bucket.bucket}/${aws_s3_object.bucketobject.key} /tmp/playbook.yml"
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
              "echo '${jsonencode(var.extravars)}' > /tmp/extravars.json",
              "ansible-playbook -i localhost, -e 'ansible_connection=local ansible_python_interpreter=/usr/bin/python3' -e @/tmp/extravars.json /tmp/playbook.yml"
            ]
          }
        }
      },
      {
        "name": "CreateAmi",
        "action": "aws:createImage",
        "nextStep": "TerminateInstance",
        "isEnd": false,
        "inputs": {
          "InstanceId": "{{ LaunchInstance.InstanceIds }}",
          "ImageName": "${var.platform}-${var.stage}-ami-${var.name}"
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
}

# Run document

resource "null_resource" "null_ssm_run" {
  triggers = {
    playbook_checksum = filemd5(var.playbook)
    extravars_hash    = md5(jsonencode(var.extravars))
  }
  depends_on = [aws_ssm_document.ssmdocument_main]
  provisioner "local-exec" {
    environment = {
      AWS_ACCESS_KEY_ID     = var.aws_credentials.access_key
      AWS_SECRET_ACCESS_KEY = var.aws_credentials.secret_key
      AWS_DEFAULT_REGION    = var.aws_credentials.region
    }
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

data "aws_ami" "generated_ami" {
  most_recent = true
  owners = ["self"]
  filter {
    name   = "name"
    values = ["${var.platform}-${var.stage}-ami-${var.name}"]
  }
  depends_on = [null_resource.null_ssm_run]
}