# Instance Outputs
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "ARN of the EC2 instance"
  value       = aws_instance.this.arn
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.this.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.this.private_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.this.public_dns
}

output "instance_private_dns" {
  description = "Private DNS name of the EC2 instance"
  value       = aws_instance.this.private_dns
}

output "instance_availability_zone" {
  description = "Availability zone of the EC2 instance"
  value       = aws_instance.this.availability_zone
}

output "instance_subnet_id" {
  description = "Subnet ID of the EC2 instance"
  value       = aws_instance.this.subnet_id
}

output "instance_vpc_security_group_ids" {
  description = "List of security group IDs attached to the EC2 instance"
  value       = aws_instance.this.vpc_security_group_ids
}

output "instance_key_name" {
  description = "Key name of the EC2 instance"
  value       = aws_instance.this.key_name
}

output "instance_iam_instance_profile" {
  description = "IAM instance profile of the EC2 instance"
  value       = aws_instance.this.iam_instance_profile
}

# Storage Outputs
output "root_block_device" {
  description = "Root block device information"
  value = {
    volume_id   = aws_instance.this.root_block_device[0].volume_id
    volume_size = aws_instance.this.root_block_device[0].volume_size
    volume_type = aws_instance.this.root_block_device[0].volume_type
    encrypted   = aws_instance.this.root_block_device[0].encrypted
  }
}

output "ebs_block_devices" {
  description = "EBS block devices information"
  value = [
    for device in aws_instance.this.ebs_block_device : {
      device_name = device.device_name
      volume_id   = device.volume_id
      volume_size = device.volume_size
      volume_type = device.volume_type
      encrypted   = device.encrypted
    }
  ]
}

# CloudWatch Outputs
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = var.enable_cloudwatch_agent ? aws_cloudwatch_log_group.instance_logs[0].name : null
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = var.enable_cloudwatch_agent ? aws_cloudwatch_log_group.instance_logs[0].arn : null
}

# Backup Outputs
output "backup_vault_name" {
  description = "Name of the backup vault"
  value       = var.enable_backup ? aws_backup_vault.main[0].name : null
}

output "backup_plan_id" {
  description = "ID of the backup plan"
  value       = var.enable_backup ? aws_backup_plan.main[0].id : null
}

# Connection Information
output "ssh_connection_command" {
  description = "SSH connection command"
  value = var.key_name != null ? (
    var.associate_public_ip_address ? 
    "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_instance.this.public_ip}" :
    "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_instance.this.private_ip}"
  ) : null
}

output "ssm_connection_command" {
  description = "AWS Systems Manager Session Manager connection command"
  value = "aws ssm start-session --target ${aws_instance.this.id}"
}