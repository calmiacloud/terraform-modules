variable "name" {
  type        = string
}

variable "Product" {
  type        = string
}

variable "Environment" {
  type        = string
}

variable "Vpc" {
  type = object({
    Cidr        = string
    DnsSupport  = bool
    Ipv6Support = bool
  })
}

variable "Subnets" {
  type = object({
    Public = optional(list(object({
      Name     = string
      Cidr     = string
    })), [])
    Nat = optional(list(object({
      Name = string
      Cidr = string
    })), [])
    Private = optional(list(object({
      Name = string
      Cidr = string
    })), [])
  })
  default = {
    Public  = []
    Nat     = []
    Private = []
  }
}