# Terraform Backend Configuration Template
# This file should be customized for each environment

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2"
    }
  }

  # Uncomment and configure for remote state management
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "environments/{environment}/terraform.tfstate"
  #   region         = "us-west-2"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-locks"
  #   
  #   # Optional: Use workspace for environment isolation
  #   workspace_key_prefix = "env"
  # }
}

# S3 Bucket for Terraform State (create this manually or with separate configuration)
# resource "aws_s3_bucket" "terraform_state" {
#   bucket = "your-terraform-state-bucket"
#   
#   tags = {
#     Name        = "Terraform State Bucket"
#     Environment = "shared"
#     ManagedBy   = "Terraform"
#   }
# }

# resource "aws_s3_bucket_versioning" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_s3_bucket_encryption" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id

#   server_side_encryption_configuration {
#     rule {
#       apply_server_side_encryption_by_default {
#         sse_algorithm = "AES256"
#       }
#     }
#   }
# }

# resource "aws_s3_bucket_public_access_block" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# DynamoDB Table for State Locking
# resource "aws_dynamodb_table" "terraform_locks" {
#   name           = "terraform-state-locks"
#   billing_mode   = "PAY_PER_REQUEST"
#   hash_key       = "LockID"

#   attribute {
#     name = "LockID"
#     type = "S"
#   }

#   tags = {
#     Name        = "Terraform State Locks"
#     Environment = "shared"
#     ManagedBy   = "Terraform"
#   }
# }