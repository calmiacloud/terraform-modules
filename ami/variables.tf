variable "Name" {
  type        = string
}

variable "Product" {
  type        = string
}

variable "Stage" {
  type        = string
}

variable "Source" {
  type  = string
}

variable "Instance" {
  type = object({
    ParentImage    = string
    InstanceType   = string
    KeyPair        = string
    Subnet         = string
    SecurityGroup  = string
  })
}

variable "ExtraVars" {
  type    = any
  default = {}
}