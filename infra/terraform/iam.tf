resource "aws_iam_role" "lambda_exec" {
  name               = "${local.prefix}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

data "aws_iam_policy_document" "lambda_trust" {
  statement { 
    actions = ["sts:AssumeRole"] 
    principals { 
      type = "Service" 
      identifiers = ["lambda.amazonaws.com", "states.amazonaws.com"] 
    } 
  }
}

resource "aws_iam_role_policy" "lambda_inline" {
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { 
        Effect = "Allow", 
        Action = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"], 
        Resource = "*" 
      },
      { 
        Effect = "Allow", 
        Action = ["lambda:InvokeFunction"], 
        Resource = [
          "${aws_lambda_function.normalize.arn}",
          "${aws_lambda_function.deweaponize.arn}",
          "${aws_lambda_function.attachments.arn}",
          "${aws_lambda_function.pii.arn}",
          "${aws_lambda_function.template.arn}"
        ]
      },
      { 
        Effect = "Allow", 
        Action = ["s3:GetObject","s3:PutObject"], 
        Resource = [
          "${aws_s3_bucket.raw.arn}/*", 
          "${aws_s3_bucket.sanitized.arn}/*"
        ]
      },
      { 
        Effect = "Allow", 
        Action = ["sqs:ReceiveMessage","sqs:DeleteMessage","sqs:GetQueueAttributes"], 
        Resource = aws_sqs_queue.ingest.arn 
      },
      { 
        Effect = "Allow", 
        Action = ["dynamodb:PutItem","dynamodb:UpdateItem","dynamodb:GetItem","dynamodb:Query"], 
        Resource = aws_dynamodb_table.templates.arn 
      },
      { 
        Effect = "Allow", 
        Action = ["kms:Decrypt","kms:Encrypt","kms:GenerateDataKey"], 
        Resource = aws_kms_key.harborsim.arn 
      }
    ]
  })
}

