# Monitoring Variables
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

# CloudWatch Variables
variable "log_retention_days" {
  description = "Number of days to retain logs in CloudWatch"
  type        = number
  default     = 30
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "enable_enhanced_monitoring" {
  description = "Enable enhanced monitoring for RDS instances"
  type        = bool
  default     = true
}

# Alerting Variables
variable "notification_email" {
  description = "Email address for CloudWatch alerts"
  type        = string
  default     = ""
}

variable "enable_slack_notifications" {
  description = "Enable Slack notifications"
  type        = bool
  default     = false
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

# Alarm Thresholds
variable "cpu_threshold_high" {
  description = "CPU utilization threshold for high alarm"
  type        = number
  default     = 80
  validation {
    condition     = var.cpu_threshold_high > 0 && var.cpu_threshold_high <= 100
    error_message = "CPU threshold must be between 0 and 100."
  }
}

variable "memory_threshold_high" {
  description = "Memory utilization threshold for high alarm"
  type        = number
  default     = 80
  validation {
    condition     = var.memory_threshold_high > 0 && var.memory_threshold_high <= 100
    error_message = "Memory threshold must be between 0 and 100."
  }
}

variable "disk_threshold_high" {
  description = "Disk utilization threshold for high alarm"
  type        = number
  default     = 85
  validation {
    condition     = var.disk_threshold_high > 0 && var.disk_threshold_high <= 100
    error_message = "Disk threshold must be between 0 and 100."
  }
}

# Instance Variables
variable "instance_ids" {
  description = "List of EC2 instance IDs to monitor"
  type        = list(string)
  default     = []
}

variable "rds_instance_ids" {
  description = "List of RDS instance IDs to monitor"
  type        = list(string)
  default     = []
}

variable "load_balancer_arns" {
  description = "List of load balancer ARNs to monitor"
  type        = list(string)
  default     = []
}