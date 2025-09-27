# ================================
# Development Environment Configuration
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

  # Backend configuration for Terraform state (commented out for local testing)
  # backend "s3" {
  #   bucket         = "terraform-state-dev1-bucket"
  #   key            = "dev1/terraform.tfstate"
  #   region         = "us-west-2"
  #   encrypt        = true
  #   use_lockfile   = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev1"
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Owner       = "DevOps Team"
      CostCenter  = "Engineering"
      CreatedDate = timestamp()
    }
  }
}

# ================================
# Base Infrastructure Module
# ================================

module "base_infrastructure" {
  source = "../../02-mod-base"

  # Environment configuration
  environment  = "dev"
  project_name = var.project_name
  aws_region   = var.aws_region

  # Instance configuration
  key_name             = var.key_name
  instance_count       = 1
  instance_count_string = var.instance_count_string

  # Auto Scaling configuration (disabled for dev)
  enable_auto_scaling = false
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  # Security configuration
  allowed_cidr_blocks = var.allowed_cidr_blocks

  # Monitoring configuration
  notification_email = var.notification_email
  
  # Backup configuration
  enable_backup = var.enable_backup
}
