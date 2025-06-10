variable "Zone" {
  type        = string
}

variable "Records" {
  type = map(object({
    Type    = string
    Ttl     = number
    Values  = list(string)
  }))
}
