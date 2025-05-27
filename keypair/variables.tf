variable "Name" {
  type        = string
}

variable "PublicKeyB64" {
  type        = string
}

variable "Tags" {
  type = object({
    Project = string
    Repo    = string
    Stage   = string
  })
}