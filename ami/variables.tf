variable "name" {
  type = string
}

variable "playbooks_dir" {
  type = string
}

variable "instance" {
  type = object({
    parentami     = string
    instancetype  = string
    keypair       = string
    subnet        = string
    securitygroup = string
  })
}

variable "extravars" {
  type    = any
  default = {}
}

variable "tags" {
  type = any
}