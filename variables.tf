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
