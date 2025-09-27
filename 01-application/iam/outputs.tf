# IAM Role Outputs
output "iam_role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.ec2_role.arn
}

output "iam_role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.ec2_role.name
}

output "iam_role_id" {
  description = "ID of the IAM role"
  value       = aws_iam_role.ec2_role.id
}

# Instance Profile Outputs
output "instance_profile_arn" {
  description = "ARN of the instance profile"
  value       = aws_iam_instance_profile.ec2_profile.arn
}

output "instance_profile_name" {
  description = "Name of the instance profile"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "instance_profile_id" {
  description = "ID of the instance profile"
  value       = aws_iam_instance_profile.ec2_profile.id
}