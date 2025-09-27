# IAM Role Variables
variable "role_name" {
  description = "Name of the IAM role"
  type        = string
  default     = "enterprise-ec2-role"
}

variable "instance_profile_name" {
  description = "Name of the instance profile"
  type        = string
  default     = "enterprise-ec2-instance-profile"
}

variable "enable_ssm_access" {
  description = "Enable AWS Systems Manager access"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_agent" {
  description = "Enable CloudWatch Agent access"
  type        = bool
  default     = true
}

variable "enable_secrets_manager" {
  description = "Enable AWS Secrets Manager access"
  type        = bool
  default     = true
}

variable "enable_s3_access" {
  description = "Enable S3 access for logs and artifacts"
  type        = bool
  default     = true
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs to grant access to"
  type        = list(string)
  default     = []
}

variable "custom_policies" {
  description = "List of custom policy ARNs to attach to the role"
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}