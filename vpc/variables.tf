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
    Public  = list(object({
      Name = string
      Cidr = list(string)
    }))
    Nat     = list(object({
      Name = string
      Cidr = list(string)
    }))
    Private = list(object({
      Name = string
      Cidr = list(string)
    }))
  })
}

variable "Tags" {
  type = object({
    Project = string
    Repo    = string
    Stage   = string
  })
}
