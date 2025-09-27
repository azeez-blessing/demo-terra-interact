# =====================================
# VARIABLES
# =====================================
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "cloudtrail-splunk"
}

variable "splunk_hec_endpoint" {
  description = "Splunk HTTP Event Collector endpoint URL"
  type        = string
  # Example: "https://your-splunk.com:8088/services/collector/event"
}

variable "splunk_hec_token" {
  description = "Splunk HEC authentication token"
  type        = string
  sensitive   = true
}

variable "cloudtrail_bucket_name" {
  description = "S3 bucket name for CloudTrail logs (globally unique)"
  type        = string
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

