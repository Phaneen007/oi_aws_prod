variable "user_pool_name" {
  description = "Name of the Cognito User Pool"
  type        = string
}

variable "cognito_domain" {
  description = "Cognito domain prefix"
  type        = string
}

variable "callback_urls" {
  description = "List of callback URLs for OAuth"
  type        = list(string)
}

variable "logout_urls" {
  description = "List of logout URLs"
  type        = list(string)
}

variable "enable_mfa" {
  description = "Enable MFA for the user pool"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "production"
}