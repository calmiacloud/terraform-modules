variable "name" {
  type = string
}

variable "role" {
  type = string
}

variable "path" {
  type = string
}

variable "environment" {
  type = map(any)
  default = {}
}