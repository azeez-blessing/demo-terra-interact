# ================================
# QA Environment Configuration
# ================================
# This configuration uses the base module to provision infrastructure

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Backend configuration for Terraform state
  backend "s3" {
    bucket         = "terraform-state-qa-bucket"
    key            = "qa/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment   = "qa"
      Project       = var.project_name
      ManagedBy     = "Terraform"
      Owner         = "DevOps Team"
      CostCenter    = "Engineering"
      CreatedDate   = timestamp()
    }
  }
}

# ================================
# Base Infrastructure Module
# ================================

module "base_infrastructure" {
  source = "../../mod-base"
  
  # Environment configuration
  environment  = "staging"
  project_name = var.project_name
  aws_region   = var.aws_region
  
  # Instance configuration
  key_name       = var.key_name
  instance_count = 2
  
  # Auto Scaling configuration (enabled for QA)
  enable_auto_scaling = true
  min_size           = 1
  max_size           = 3
  desired_capacity   = 2
  
  # Security configuration
  allowed_cidr_blocks = var.allowed_cidr_blocks
  
  # Monitoring configuration
  notification_email = var.notification_email
}

# ================================
# Outputs
# ================================

output "vpc_id" {
  description = "VPC ID from base module"
  value       = module.base_infrastructure.vpc_id
}

output "auto_scaling_group_name" {
  description = "Auto Scaling Group name"
  value       = module.base_infrastructure.auto_scaling_group_name
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.base_infrastructure.cloudwatch_dashboard_url
}

output "security_group_ids" {
  description = "Security group IDs"
  value       = module.base_infrastructure.security_group_ids
}