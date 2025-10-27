resource "aws_s3_bucket" "raw" { 
  bucket = "${local.prefix}-raw"
  tags   = local.tags_common
}

resource "aws_s3_bucket" "sanitized" { 
  bucket = "${local.prefix}-sanitized"
  tags   = local.tags_common
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id
  rule { 
    apply_server_side_encryption_by_default { 
      sse_algorithm = "aws:kms" 
      kms_master_key_id = aws_kms_key.harborsim.arn 
    } 
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sanitized" {
  bucket = aws_s3_bucket.sanitized.id
  rule { 
    apply_server_side_encryption_by_default { 
      sse_algorithm = "aws:kms" 
      kms_master_key_id = aws_kms_key.harborsim.arn 
    } 
  }
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "sanitized" {
  bucket = aws_s3_bucket.sanitized.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

