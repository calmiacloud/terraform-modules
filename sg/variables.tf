variable "Name" {
  type        = string
}

variable "Product" {
  type        = string
}

variable "Environment" {
  type        = string
}

variable "VpcId" {
  type        = string
}

variable "Ingress" {
  type = list(object({
    FromPort   = number
    ToPort     = number
    protocol    = string
    Cidr   = string
  }))
  default = []
}

variable "Egress" {
  type = list(object({
    FromPort   = number
    ToPort     = number
    protocol    = string
    Cidr   = string
  }))
  default = [
    FromPort   = number
    ToPort     = number
    protocol    = "-1"
    Cidr   = "0.0.0.0/0"
  ]


    protocol    = "-1"
  from_port   = 0
  to_port     = 0

  # Origen: cualquier dirección IPv4
  cidr_blocks = ["0.0.0.0/0"]
}
