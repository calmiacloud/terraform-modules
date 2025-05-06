variable "Name" {
  type        = string
}

variable "Product" {
  type        = string
}

variable "Environment" {
  type        = string
}

variable "Playbook" {
  type  = string
}

variable "Instance" {
  type = object({
    image_id        = string
    instance_type   = string
    keypair         = string
    subnet          = string
    security_group  = string
    instanceprofile = string
  })
}

variable "ExtraVars" {
  type = map(any)
  default = {}
}