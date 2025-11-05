output "user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.openwebui_pool.id
}

output "user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.openwebui_pool.arn
}

output "user_pool_endpoint" {
  description = "Cognito User Pool endpoint"
  value       = aws_cognito_user_pool.openwebui_pool.endpoint
}

output "client_id" {
  description = "Cognito User Pool Client ID"
  value       = aws_cognito_user_pool_client.openwebui_client.id
}

output "client_secret" {
  description = "Cognito User Pool Client Secret"
  value       = aws_cognito_user_pool_client.openwebui_client.client_secret
  sensitive   = true
}

output "client_secret_arn" {
  description = "ARN of the Cognito client secret in Secrets Manager"
  value       = aws_secretsmanager_secret.cognito_client_secret.arn
}

output "cognito_domain" {
  description = "Cognito domain"
  value       = aws_cognito_user_pool_domain.openwebui_domain.domain
}

output "issuer_url" {
  description = "OIDC issuer URL"
  value       = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.openwebui_pool.id}"
}

data "aws_region" "current" {}