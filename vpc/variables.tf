variable "Name" {
  type        = string
}

variable "Product" {
  type        = string
}

variable "Stage" {
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
    Public = optional(
      list(object({
        Name             = string
        Cidr             = string
        AdditionalRoutes = optional(
          list(object({
            Cidr   = string
            Type   = string
            Target = string
          })),
          []
        )
      })),
      []
    )
    Nat = optional(
      list(object({
        Name             = string
        Cidr             = string
        AdditionalRoutes = optional(
          list(object({
            Cidr   = string
            Type   = string
            Target = string
          })),
          []
        )
      })),
      []
    )
    Private = optional(
      list(object({
        Name             = string
        Cidr             = string
        AdditionalRoutes = optional(
          list(object({
            Cidr   = string
            Type   = string
            Target = string
          })),
          []
        )
      })),
      []
    )
  })
  default = {
    Public  = []
    Nat     = []
    Private = []
  }
  validation {
    condition = alltrue([
      for s in concat(var.Subnets.Public, var.Subnets.Nat, var.Subnets.Private) :
      alltrue([
        for r in lookup(s, "AdditionalRoutes", []) :
        contains(["NetworkInterface", "Otro"], r.Type)
      ])
    ])
    error_message = <<-EOF
      'AdditionalRoute.Type' tiene ID invalido
    EOF
  }
}