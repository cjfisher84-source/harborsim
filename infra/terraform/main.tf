resource "aws_lambda_function" "normalize" {
  function_name = "${local.prefix}-normalize"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "handler.handler"
  runtime       = "python3.11"
  filename      = "${path.module}/../../dist/${var.service_name}-normalize.zip"
  
  environment {
    variables = { 
      RAW_BUCKET = aws_s3_bucket.raw.id 
    }
  }
}

resource "aws_lambda_function" "deweaponize" {
  function_name = "${local.prefix}-deweaponize"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "handler.handler"
  runtime       = "python3.11"
  filename      = "${path.module}/../../dist/${var.service_name}-deweaponize.zip"
  
  environment {
    variables = { 
      RAW_BUCKET = aws_s3_bucket.raw.id 
    }
  }
}

resource "aws_lambda_function" "attachments" {
  function_name = "${local.prefix}-attachments"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "handler.handler"
  runtime       = "python3.11"
  filename      = "${path.module}/../../dist/${var.service_name}-attachments.zip"
}

resource "aws_lambda_function" "pii" {
  function_name = "${local.prefix}-pii"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "handler.handler"
  runtime       = "python3.11"
  filename      = "${path.module}/../../dist/${var.service_name}-pii.zip"
}

resource "aws_lambda_function" "template" {
  function_name = "${local.prefix}-template"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "handler.handler"
  runtime       = "python3.11"
  filename      = "${path.module}/../../dist/${var.service_name}-template.zip"
  
  environment {
    variables = {
      RAW_BUCKET        = aws_s3_bucket.raw.id
      SANITIZED_BUCKET  = aws_s3_bucket.sanitized.id
      TEMPLATES_TABLE   = aws_dynamodb_table.templates.name
    }
  }
}

