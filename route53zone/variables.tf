variable "Name" {
  type        = string
}

variable "Domain" {
  type        = string
}

variable "Type" {
  type        = string
  validation {
    condition     = var.Type == "Public" || var.Type == "Private"
    error_message = "El tipo debe ser 'Public' o 'Private'."
  }
}

variable "Vpc" {
  type        = string
  validation {
    condition = var.Type == "Public" || (var.Type == "Private" && length(var.vpc_ids) > 0)
    error_message = "Debe especificarse al menos una VPC si el tipo de zona es 'Private'."
  }
}

variable "Tags" {
  type = object({
    Project = string
    Repo    = string
    Stage   = string
  })
}
