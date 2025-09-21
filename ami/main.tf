resource "aws_instance" "example" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  tags = var.tags
}

# Este recurso soporta los default_tags definidos en el proveedor AWS.
# Si el proveedor tiene default_tags configurados, se combinarán automáticamente con los tags definidos aquí.
# Si hay claves duplicadas, el valor de 'tags' en este recurso sobrescribirá el default_tag correspondiente.

variable "ami_id" {
  description = "AMI ID para la instancia EC2"
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
}

variable "tags" {
  description = "Tags adicionales para la instancia EC2"
  type        = map(string)
  default     = {}
}
