variable "Name" {
  type        = string
}

variable "tags" {
  type = object({
    Project = string
    Repo    = string
    Stage   = string
  })
}

variable "PublicKeyB64" {
  type        = string
}
