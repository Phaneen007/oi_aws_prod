# OpenRouter API Key (placeholder - to be updated after deployment)
resource "aws_secretsmanager_secret" "openrouter_api_key" {
  name_prefix = "openwebui-prod-openrouter-api-key-"
  description = "OpenRouter API Key for Open WebUI"
}

resource "aws_secretsmanager_secret_version" "openrouter_api_key_version" {
  secret_id     = aws_secretsmanager_secret.openrouter_api_key.id
  secret_string = "placeholder-configure-after-deployment"
}

# Aurora PostgreSQL Database Credentials
resource "aws_secretsmanager_secret" "aurora_credentials" {
  name_prefix = "openwebui-prod-aurora-creds-"
  description = "Aurora PostgreSQL credentials for Open WebUI"
}

resource "aws_secretsmanager_secret_version" "aurora_credentials_version" {
  secret_id = aws_secretsmanager_secret.aurora_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    engine   = "postgres"
    host     = module.aurora.cluster_endpoint
    port     = 5432
    dbname   = var.db_name
  })
}

# MCPO API Key (if using MCPO module)
resource "random_password" "mcpo_api_key" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "mcpo_api_key_secret" {
  name_prefix = "openwebui-prod-mcpo-api-key-"
}

resource "aws_secretsmanager_secret_version" "mcpo_api_key_secret_version" {
  secret_id     = aws_secretsmanager_secret.mcpo_api_key_secret.id
  secret_string = random_password.mcpo_api_key.result
}

# GitLab Token (if using MCPO module)
resource "aws_secretsmanager_secret" "gitlab_token_secret" {
  name_prefix = "openwebui-prod-gitlab-token-"
}

resource "aws_secretsmanager_secret_version" "gitlab_token_secret_version" {
  secret_id     = aws_secretsmanager_secret.gitlab_token_secret.id
  secret_string = "placeholder-configure-if-needed"
}

# Linear Token (if using MCPO module)
resource "aws_secretsmanager_secret" "linear_token_secret" {
  name_prefix = "openwebui-prod-linear-token-"
}

resource "aws_secretsmanager_secret_version" "linear_token_secret_version" {
  secret_id     = aws_secretsmanager_secret.linear_token_secret.id
  secret_string = "placeholder-configure-if-needed"
}