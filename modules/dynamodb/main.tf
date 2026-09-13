variable "project" {
  type = string
}

variable "owner" {
  type = string
}

resource "aws_dynamodb_table" "products" {
  name         = "${var.project}-products"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "product_id"

  attribute {
    name = "product_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Project = var.project
    Owner   = var.owner
  }
}

output "table_name" {
  value = aws_dynamodb_table.products.name
}

output "table_arn" {
  value = aws_dynamodb_table.products.arn
}
