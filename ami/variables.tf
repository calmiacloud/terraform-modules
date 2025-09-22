variable "playbooks_dir" {
  type = string
}

variable "instance" {
  type = object({
    parentami     = string
    model  = string
    keypair       = string
    subnet        = string
    securitygroup = string
  })
}

variable "extravars" {
  type    = any
  default = {}
}