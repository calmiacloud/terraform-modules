variable "Zone" {
  type        = string
}

variable "Records" {
  type = map(object({
    Type    = string
    Ttl     = number
    Records  = list(string)
  }))
}
