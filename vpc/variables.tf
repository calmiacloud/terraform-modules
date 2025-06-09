variable "Name" {
  type        = string
}

variable "Vpc" {
  type = object({
    Cidr        = string
    Ipv6Support = bool
  })
}

variable "Subnets" {
  type = object({
    Public  = map(list(string))
    Nat     = optional(map(list(string)))
    Private = optional(map(list(string)))
  })
}

variable "Tags" {
  type = object({
    Project = string
    Repo    = string
    Stage   = string
  })
}
