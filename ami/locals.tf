locals {
  subproject_prefix = {
    web               = "web"
    newsletter        = "newsletter"
    transactional     = "transactional"
    billing           = "billing"
    authentication    = "auth"
    lista_usuarios    = "users"
    statistics        = "stats"
    monitoring        = "monitoring"
  }

  resource_prefix = {
    s3_bucket           = "s3"
    dynamodb_table      = "ddb"
    ec2_instance        = "ec2"
    ec2_security_group  = "sg"
    ec2_keypair         = "keypair"
    iam_role            = "role"
    iam_policy          = "policy"
	
  }
}