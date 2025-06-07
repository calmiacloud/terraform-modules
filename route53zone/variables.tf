variable "Name" {
  type        = string
}

variable "Domain" {
  type        = string
}

variable "Tags" {
  type = object({
    Project = string
    Repo    = string
    Stage   = string
  })
}
