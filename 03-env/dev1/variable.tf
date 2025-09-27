# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "enterprise-app"
}

variable "key_name" {
  description = "EC2 Key Pair name"
  type        = string
  default     = null
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access resources"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "notification_email" {
  description = "Email for CloudWatch notifications"
  type        = string
  default     = ""
}

variable "enable_backup" {
  description = "Enable automated backup for dev environment"
  type        = bool
  default     = false  # Disabled for dev to save costs
}

variable "instance_count_string" {
  description = "Number of instances as a string for dev environment"
  type        = string
  default     = "1"
}

