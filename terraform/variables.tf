# AWS Configuration
variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS Profile"
  type        = string
  default     = "default"
}

# Project Configuration
variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "openwebui-prod"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "production"
}

# Database Configuration
variable "db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "openwebui"
}

variable "db_username" {
  description = "Master username for Aurora PostgreSQL"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for Aurora PostgreSQL"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "Instance class for Aurora database"
  type        = string
  default     = "db.t4g.medium"
}

variable "db_instance_count" {
  description = "Number of Aurora instances"
  type        = number
  default     = 1
}

variable "db_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot when destroying database"
  type        = bool
  default     = true
}

# S3 Configuration
variable "s3_bucket_name" {
  description = "Name of the S3 bucket for file storage"
  type        = string
}

variable "s3_enable_versioning" {
  description = "Enable versioning for S3 bucket"
  type        = bool
  default     = true
}

# Cognito Configuration
variable "cognito_user_pool_name" {
  description = "Name of the Cognito User Pool"
  type        = string
  default     = "openwebui-prod-users"
}

variable "cognito_domain" {
  description = "Cognito domain prefix (must be globally unique)"
  type        = string
}

variable "cognito_enable_mfa" {
  description = "Enable MFA for Cognito User Pool"
  type        = bool
  default     = false
}

# ECS Configuration
variable "ecs_openwebui_cpu" {
  description = "CPU units for Open WebUI task"
  type        = number
  default     = 2048
}

variable "ecs_openwebui_memory" {
  description = "Memory for Open WebUI task"
  type        = number
  default     = 4096
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}