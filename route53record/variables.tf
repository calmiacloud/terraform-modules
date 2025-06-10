variable "Zone" {
  type        = string
}

variable "Records" {
  description = "Lista de definiciones de registros Route53"
  type = list(object({
    Name   = string
    Type   = string
    Ttl    = number
    Values = list(string)     # antes era Records = list(string)
  }))
}
