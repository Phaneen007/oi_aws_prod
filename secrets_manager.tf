# OpenRouter API Key (placeholder - to be updated after deployment)
resource "aws_secretsmanager_secret" "openrouter_api_key" {
  name_prefix = "openwebui-prod-openrouter-api-key-"
  description = "OpenRouter API Key for Open WebUI"
}

resource "aws_secretsmanager_secret_version" "openrouter_api_key_version" {
  secret_id     = aws_secretsmanager_secret.openrouter_api_key.id
  secret_string = "placeholder-configure-after-deployment"
}