variable "name" {
  type        = string
}

variable "vpc_cidr" {
  type        = string
}

variable "dns_support" {
  type        = bool
  default     = false
}

variable "ipv6_support" {
  type        = bool
  default     = false
}