variable "Name" {
  type        = string
}

variable "Product" {
  type        = string
}

variable "Environment" {
  type        = string
}

variable "Vpc" {
  description = "Configuración de la VPC"
  type = object({
    VpcCidr    = string
    DnsSupport = bool
    Ipv6Support = bool
  })
}

variable "Subnets" {
  type = object({
    Public  = optional(list(object({
      Name     = string
      Cidr     = string
      Internet = bool
    })), [])
    Private = optional(list(object({
      Name = string
      Cidr = string
      Nat  = bool
    })), [])
  })
  default = {
    Public  = []
    Private = []
  }
}