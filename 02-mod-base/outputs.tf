# ================================
# Outputs for Enterprise Base Module
# ================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "instance_ids" {
  description = "IDs of the EC2 instances"
  value       = var.enable_auto_scaling ? [] : [for instance in module.ec2_instances : instance.instance_id]
}

output "instance_private_ips" {
  description = "Private IPs of the EC2 instances"
  value       = var.enable_auto_scaling ? [] : [for instance in module.ec2_instances : instance.instance_private_ip]
}

output "auto_scaling_group_name" {
  description = "Name of the Auto Scaling Group (if enabled)"
  value       = var.enable_auto_scaling ? aws_autoscaling_group.main[0].name : null
}

output "ssh_connection_commands" {
  description = "SSH connection commands for instances"
  value       = var.enable_auto_scaling ? [] : [for instance in module.ec2_instances : instance.ssh_connection_command]
}

output "ssm_connection_commands" {
  description = "AWS Systems Manager Session Manager connection commands"
  value       = var.enable_auto_scaling ? [] : [for instance in module.ec2_instances : instance.ssm_connection_command]
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.cloudwatch_dashboard_url
}

output "security_group_ids" {
  description = "Security group IDs"
  value = {
    app_security_group_id        = module.security.app_security_group_id
    database_security_group_id   = module.security.database_security_group_id
    management_security_group_id = module.security.management_security_group_id
  }
}

output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = module.security.kms_key_id
}

output "environment_config" {
  description = "Current environment configuration"
  value       = local.current_config
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.network.private_subnet_ids
}

output "database_subnet_ids" {
  description = "IDs of the database subnets"
  value       = module.network.database_subnet_ids
}