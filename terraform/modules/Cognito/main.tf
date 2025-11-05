# Cognito User Pool for Open WebUI OAuth

resource "aws_cognito_user_pool" "openwebui_pool" {
  name = var.user_pool_name

  # Password policy
  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  # Auto-verified attributes
  auto_verified_attributes = ["email"]

  # Username attributes
  username_attributes = ["email"]

  # User attribute schema
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    required            = false
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  # MFA configuration
  mfa_configuration = var.enable_mfa ? "OPTIONAL" : "OFF"

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # User pool add-ons
  user_pool_add_ons {
    advanced_security_mode = "AUDIT"
  }

  tags = {
    Name        = var.user_pool_name
    Environment = var.environment
  }
}

# User Pool Domain
resource "aws_cognito_user_pool_domain" "openwebui_domain" {
  domain       = var.cognito_domain
  user_pool_id = aws_cognito_user_pool.openwebui_pool.id
}

# User Pool Client for Open WebUI
resource "aws_cognito_user_pool_client" "openwebui_client" {
  name         = "${var.user_pool_name}-client"
  user_pool_id = aws_cognito_user_pool.openwebui_pool.id

  generate_secret = true

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  supported_identity_providers = ["COGNITO"]

  # Token validity
  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"

  # Read and write attributes
  read_attributes = [
    "email",
    "email_verified",
    "name",
    "preferred_username"
  ]

  write_attributes = [
    "email",
    "name",
    "preferred_username"
  ]

  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_USER_PASSWORD_AUTH"
  ]
}

# Store client secret in Secrets Manager
resource "aws_secretsmanager_secret" "cognito_client_secret" {
  name_prefix = "${var.user_pool_name}-client-secret-"
  description = "Cognito client secret for Open WebUI"
}

resource "aws_secretsmanager_secret_version" "cognito_client_secret_version" {
  secret_id     = aws_secretsmanager_secret.cognito_client_secret.id
  secret_string = aws_cognito_user_pool_client.openwebui_client.client_secret
}