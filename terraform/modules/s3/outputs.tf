output "bucket_id" {
  description = "S3 bucket ID"
  value       = aws_s3_bucket.openwebui_storage.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.openwebui_storage.arn
}

output "bucket_domain_name" {
  description = "S3 bucket domain name"
  value       = aws_s3_bucket.openwebui_storage.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "S3 bucket regional domain name"
  value       = aws_s3_bucket.openwebui_storage.bucket_regional_domain_name
}