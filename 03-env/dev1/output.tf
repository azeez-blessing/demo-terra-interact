
# ================================
# Outputs
# ================================

output "vpc_id" {
  description = "VPC ID from base module"
  value       = module.base_infrastructure.vpc_id
}

output "instance_ids" {
  description = "EC2 instance IDs"
  value       = module.base_infrastructure.instance_ids
}

output "ssh_connection_commands" {
  description = "SSH connection commands"
  value       = module.base_infrastructure.ssh_connection_commands
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.base_infrastructure.cloudwatch_dashboard_url
}

output "security_group_ids" {
  description = "Security group IDs"
  value       = module.base_infrastructure.security_group_ids
}