# Main Terraform configuration integrating all modules
# This file creates S3, Aurora, and Cognito resources

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

# Aurora PostgreSQL Module
module "aurora" {
  source = "./modules/aurora"

  cluster_name            = "${var.project_name}-aurora"
  database_name           = var.db_name
  master_username         = var.db_username
  master_password         = var.db_password
  vpc_id                  = aws_vpc.default.id
  subnet_ids              = aws_subnet.webui_private_subnets[*].id
  allowed_security_groups = [module.ecs_service_openwebui_sg.id]
  instance_class          = var.db_instance_class
  instance_count          = var.db_instance_count
  backup_retention_period = var.db_backup_retention_period
  skip_final_snapshot     = var.db_skip_final_snapshot
}

# Cognito Module
module "cognito" {
  source = "./modules/Cognito"

  user_pool_name = var.cognito_user_pool_name
  cognito_domain = var.cognito_domain
  callback_urls  = ["http://${aws_lb.alb.dns_name}/oauth/oidc/callback"]
  logout_urls    = ["http://${aws_lb.alb.dns_name}"]
  enable_mfa     = var.cognito_enable_mfa
  environment    = var.environment
}