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
}

variable "Tags" {
  type = object({
    Project = string
    Repo    = string
    Stage   = string
  })
}
