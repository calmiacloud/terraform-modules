# Dummy Terraform module for AMI
resource "null_resource" "dummy_ami_module" {
	# Dummy trigger to simulate AMI creation
	triggers = {
		dummy = "ami_dummy"
	}
}

output "dummy_ami_id" {
	value       = "ami-0123456789abcdef0"
	description = "Dummy AMI ID output"
}
