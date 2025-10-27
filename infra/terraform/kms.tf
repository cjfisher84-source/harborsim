resource "aws_kms_key" "harborsim" {
  description             = "KMS for HarborSim data at rest"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.tags_common
}

resource "aws_kms_alias" "harborsim" {
  name          = "alias/${local.prefix}"
  target_key_id = aws_kms_key.harborsim.key_id
}

