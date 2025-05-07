variable "Name" {
  type = string
}

variable "Product" {
  type = string
}

variable "Environment" {
  type = string
}

variable "VpcId" {
  type = string
}

variable "Ingress" {
  type = list(object({
    FromPort = number
    ToPort   = number
    Protocol  = string
    Cidr      = string
  }))
  default = []
}

variable "Egress" {
  type = list(object({
    FromPort = number
    ToPort   = number
    Protocol  = string
    Cidr      = string
  }))
  default = [
    {
      Protocol  = "-1"
      Cidr      = "0.0.0.0/0"
    }
  ]
}
