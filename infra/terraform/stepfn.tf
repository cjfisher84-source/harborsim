resource "aws_sfn_state_machine" "pipeline" {
  name     = "${local.prefix}-pipeline"
  role_arn = aws_iam_role.lambda_exec.arn
  definition = jsonencode({
    Comment = "HarborSim sanitize pipeline",
    StartAt = "Normalize",
    States = {
      Normalize = { 
        Type = "Task", 
        Resource = aws_lambda_function.normalize.arn,
        Next = "Deweaponize" 
      },
      Deweaponize = { 
        Type = "Task", 
        Resource = aws_lambda_function.deweaponize.arn,
        Next = "Attachments" 
      },
      Attachments = { 
        Type = "Task", 
        Resource = aws_lambda_function.attachments.arn,
        Next = "PII" 
      },
      PII = { 
        Type = "Task", 
        Resource = aws_lambda_function.pii.arn,
        Next = "Template" 
      },
      Template = { 
        Type = "Task", 
        Resource = aws_lambda_function.template.arn,
        End = true 
      }
    }
  })
}

