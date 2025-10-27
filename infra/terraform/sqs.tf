resource "aws_sqs_queue" "ingest" {
  name                      = "${local.prefix}-ingest"
  message_retention_seconds = 1209600
  kms_master_key_id         = aws_kms_key.harborsim.arn
  tags                      = local.tags_common
}

