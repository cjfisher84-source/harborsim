output "raw_bucket" { value = aws_s3_bucket.raw.bucket }
output "sanitized_bucket" { value = aws_s3_bucket.sanitized.bucket }
output "ingest_queue_url" { value = aws_sqs_queue.ingest.url }
output "ddb_table" { value = aws_dynamodb_table.templates.name }
output "state_machine_arn" { value = aws_sfn_state_machine.pipeline.id }

