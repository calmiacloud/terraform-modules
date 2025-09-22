#################################
# DynamoDB Table Definition
#################################

# Se usará el provider aws.web con default_tags automáticas
resource "aws_dynamodb_table" "my_table" {
  provider     = aws.web
  name         = "${var.tags.project}-${var.tags.environment}-table"
  hash_key     = "id"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "id"
    type = "S"
  }

  # No es necesario definir tags explícitamente: default_tags del provider se aplican automáticamente
}