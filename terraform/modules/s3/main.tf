# S3 Bucket for Open WebUI file storage

resource "aws_s3_bucket" "openwebui_storage" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "openwebui_versioning" {
  bucket = aws_s3_bucket.openwebui_storage.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "openwebui_encryption" {
  bucket = aws_s3_bucket.openwebui_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "openwebui_public_access_block" {
  bucket = aws_s3_bucket.openwebui_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy
resource "aws_s3_bucket_lifecycle_configuration" "openwebui_lifecycle" {
  bucket = aws_s3_bucket.openwebui_storage.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# CORS configuration for Open WebUI
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

# Bucket policy for ECS task role access
resource "aws_s3_bucket_policy" "openwebui_policy" {
  bucket = aws_s3_bucket.openwebui_storage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECSTaskAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.ecs_task_role_arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.openwebui_storage.arn,
          "${aws_s3_bucket.openwebui_storage.arn}/*"
        ]
      }
    ]
  })
}