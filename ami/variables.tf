variable "name" {
  type  = string
}

variable "stage" {
  type  = string
}

variable "platform" {
  type  = string
}

variable "playbook" {
  type  = string
}

variable "instance" {
  type = object({
    image_id        = string
    instance_type   = string
    keypair         = string
    subnet          = string
    security_group  = string
    instanceprofile = string
  })
}

variable "extravars" {
  type = map(any)
  default = {}
}

variable "aws_credentials" {
  type  = object({
    access_key  = string
    secret_key = string
    region = string
  })
}