variable "name" {
  description = "Nombre del Security Group"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC donde se creará el SG"
  type        = string
}

variable "rule_tags" {
  description = "Etiquetas comunes para las reglas de seguridad"
  type        = map(string)
  default     = {}
}

variable "ingress_rules" {
  description = "Reglas de entrada"
  type = list(object({
    name        = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_ipv4   = string
  }))
  default = []
}

variable "egress_rules" {
  description = "Reglas de salida"
  type = list(object({
    name        = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_ipv4   = string
  }))
  default = []
}
