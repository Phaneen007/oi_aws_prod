# Main Terraform configuration - Optimized for cost-efficiency
# Uses EFS for database (SQLite) and S3 for file storage
# API Gateway with Lambda for LLM access via OpenRouter
# Fargate Spot for reduced compute costs
# No NAT Gateway - uses VPC endpoints only

# S3 Bucket for Open WebUI file storage
resource "aws_s3_bucket" "openwebui_storage" {
  bucket = var.s3_bucket_name

  tags = {
    Name        = var.s3_bucket_name
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_s3_bucket_versioning" "openwebui_versioning" {
  bucket = aws_s3_bucket.openwebui_storage.id

  versioning_configuration {
    status = var.s3_enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "openwebui_encryption" {
  bucket = aws_s3_bucket.openwebui_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "openwebui_public_access_block" {
  bucket = aws_s3_bucket.openwebui_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "openwebui_cors" {
  bucket = aws_s3_bucket.openwebui_storage.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
