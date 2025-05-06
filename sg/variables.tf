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
    from_port = number
    to_port   = number
    protocol  = string
    cidr      = string
  }))
  default = []
}

variable "Egress" {
  type = list(object({
    from_port = number
    to_port   = number
    protocol  = string
    cidr      = string
  }))
  default = [
    {
      from_port = 0
      to_port   = 0
      protocol  = "-1"
      cidr      = "0.0.0.0/0"
    }
  ]
}
