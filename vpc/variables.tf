variable "Name" {
  type        = string
}

variable "Cidr" {
  type        = string
}

variable "Ipv6Support" {
  type      = bool
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
