variable "Name" {
  type        = string
}

variable "Image" {
  type        = string
}

variable "InstanceType" {
  type        = string
}

variable "KeyPair" {
  type        = string
}

variable "Subnet" {
  type        = string
}

variable "SecurityGroup" {
  type        = string
}

variable "Tags" {
  type = object({
    Project = string
    Repo    = string
    Stage   = string
  })
}