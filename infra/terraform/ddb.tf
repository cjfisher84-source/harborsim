resource "aws_dynamodb_table" "templates" {
  name         = "${local.prefix}-templates"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "TemplateId"
  
  attribute {
    name = "TemplateId"
    type = "S"
  }
  
  attribute {
    name = "CreatedAt"
    type = "S"
  }
  
  global_secondary_index {
    name            = "CreatedAtIndex"
    hash_key        = "CreatedAt"
    projection_type = "ALL"
  }
  
  tags = local.tags_common
}

