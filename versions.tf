# Terraform Version Constraints
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Module Version Management
# This file defines the core module structure and versioning approach

locals {
  module_version = "1.0.0"
  
  # Common validation patterns
  environment_validation = {
    valid_environments = ["dev", "staging", "prod"]
  }
  
  # Common naming conventions
  naming_convention = {
    separator = "-"
    max_length = 64
  }
  
  # Common tags that should be applied to all resources
  required_tags = {
    ManagedBy     = "Terraform"
    ModuleVersion = local.module_version
  }
}

# Validation rules for all environments
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition = contains(local.environment_validation.valid_environments, var.environment)
    error_message = "Environment must be one of: ${join(", ", local.environment_validation.valid_environments)}."
  }
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  
  validation {
    condition = can(regex("^[a-zA-Z][a-zA-Z0-9-]*[a-zA-Z0-9]$", var.project_name))
    error_message = "Project name must start with a letter, contain only alphanumeric characters and hyphens, and end with alphanumeric character."
  }
  
  validation {
    condition = length(var.project_name) <= 32
    error_message = "Project name must be 32 characters or less."
  }
}

# Output the module version for tracking
output "module_version" {
  description = "Version of the Terraform module"
  value       = local.module_version
}