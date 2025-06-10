variable "Zone" {
  type        = string
}

variable "Records" {
  type = list(object({
    Name    = string
    Type    = string            # A, CNAME, MX
    Ttl     = number
    Records = any               # lista de strings para A/CNAME, lista de objetos para MX
  }))
}
