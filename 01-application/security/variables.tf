# Security Group Variables
variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
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

# Application Security Group Variables
variable "app_ports" {
  description = "List of application ports to allow"
  type        = list(number)
  default     = [80, 443, 8080, 8443]
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the application"
  type        = list(string)
  default     = []
}

variable "allowed_security_groups" {
  description = "List of security group IDs allowed to access the application"
  type        = list(string)
  default     = []
}

# Database Security Group Variables
variable "db_port" {
  description = "Database port"
  type        = number
  default     = 3306
}

variable "enable_database_sg" {
  description = "Enable database security group creation"
  type        = bool
  default     = true
}

# Load Balancer Security Group Variables
variable "enable_alb_sg" {
  description = "Enable Application Load Balancer security group creation"
  type        = bool
  default     = true
}

variable "alb_ports" {
  description = "List of ALB ports to allow"
  type        = list(number)
  default     = [80, 443]
}

# Management Security Group Variables
variable "enable_management_sg" {
  description = "Enable management/bastion security group creation"
  type        = bool
  default     = true
}

variable "management_allowed_cidrs" {
  description = "CIDR blocks allowed to access management resources"
  type        = list(string)
  default     = []
}

# KMS Variables
variable "enable_kms" {
  description = "Enable KMS key creation"
  type        = bool
  default     = true
}

variable "kms_key_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7
  validation {
    condition     = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "KMS key deletion window must be between 7 and 30 days."
  }
}

variable "kms_key_rotation_enabled" {
  description = "Enable automatic KMS key rotation"
  type        = bool
  default     = true
}