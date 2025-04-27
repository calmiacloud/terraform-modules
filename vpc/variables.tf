variable "vpc_cidr" {
  description = "CIDR de la VPC principal"
  type        = string
}

variable "enable_dns_hostnames" {
  description = "Habilitar DNS hostnames en la VPC"
  type        = bool
  default     = false
}

variable "enable_dns_support" {
  description = "Habilitar soporte de DNS en la VPC"
  type        = bool
  default     = false
}

variable "name_prefix" {
  description = "Prefijo de nombre para recursos"
  type        = string
}

variable "tags" {
  description = "Etiquetas comunes"
  type        = map(string)
  default     = {}
}
