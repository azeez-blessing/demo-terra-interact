# KMS Outputs
output "kms_key_id" {
  description = "ID of the KMS key"
  value       = var.enable_kms ? aws_kms_key.main[0].key_id : null
}

output "kms_key_arn" {
  description = "ARN of the KMS key"
  value       = var.enable_kms ? aws_kms_key.main[0].arn : null
}

output "kms_alias_name" {
  description = "Name of the KMS alias"
  value       = var.enable_kms ? aws_kms_alias.main[0].name : null
}

# Security Group Outputs
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = var.enable_alb_sg ? aws_security_group.alb[0].id : null
}

output "app_security_group_id" {
  description = "ID of the application security group"
  value       = aws_security_group.app.id
}

output "database_security_group_id" {
  description = "ID of the database security group"
  value       = var.enable_database_sg ? aws_security_group.database[0].id : null
}

output "management_security_group_id" {
  description = "ID of the management security group"
  value       = var.enable_management_sg ? aws_security_group.management[0].id : null
}

# Security Group ARNs
output "alb_security_group_arn" {
  description = "ARN of the ALB security group"
  value       = var.enable_alb_sg ? aws_security_group.alb[0].arn : null
}

output "app_security_group_arn" {
  description = "ARN of the application security group"
  value       = aws_security_group.app.arn
}

output "database_security_group_arn" {
  description = "ARN of the database security group"
  value       = var.enable_database_sg ? aws_security_group.database[0].arn : null
}

output "management_security_group_arn" {
  description = "ARN of the management security group"
  value       = var.enable_management_sg ? aws_security_group.management[0].arn : null
}

# Network ACL Outputs
output "network_acl_id" {
  description = "ID of the network ACL"
  value       = aws_network_acl.main.id
}

# CloudTrail Outputs
output "cloudtrail_name" {
  description = "Name of the CloudTrail"
  value       = aws_cloudtrail.main.name
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = aws_cloudtrail.main.arn
}

output "cloudtrail_s3_bucket_name" {
  description = "Name of the CloudTrail S3 bucket"
  value       = aws_s3_bucket.cloudtrail.bucket
}

output "cloudtrail_s3_bucket_arn" {
  description = "ARN of the CloudTrail S3 bucket"
  value       = aws_s3_bucket.cloudtrail.arn
}