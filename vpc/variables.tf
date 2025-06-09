variable "Name" {
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
    Public = optional(
      list(object({
        Name = string
        Cidr = list(string)  # Cambiado de `string` a `list(string)`
      })), 
      []
    )
    Nat = optional(
      list(object({
        Name = string
        Cidr = list(string)  # Cambiado de `string` a `list(string)`
      })), 
      []
    )
    Private = optional(
      list(object({
        Name = string
        Cidr = list(string)  # Cambiado de `string` a `list(string)`
      })), 
      []
    )
  })
  default = {
    Public  = []
    Nat     = []
    Private = []
  }
}

variable "Tags" {
  type = object({
    Project = string
    Repo    = string
    Stage   = string
  })
}
