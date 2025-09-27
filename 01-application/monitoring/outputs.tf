# SNS Topic Outputs
output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.name
}

# CloudWatch Log Group Outputs
output "application_log_group_name" {
  description = "Name of the application log group"
  value       = aws_cloudwatch_log_group.application.name
}

output "application_log_group_arn" {
  description = "ARN of the application log group"
  value       = aws_cloudwatch_log_group.application.arn
}

output "security_log_group_name" {
  description = "Name of the security log group"
  value       = aws_cloudwatch_log_group.security.name
}

output "security_log_group_arn" {
  description = "ARN of the security log group"
  value       = aws_cloudwatch_log_group.security.arn
}

output "performance_log_group_name" {
  description = "Name of the performance log group"
  value       = aws_cloudwatch_log_group.performance.name
}

output "performance_log_group_arn" {
  description = "ARN of the performance log group"
  value       = aws_cloudwatch_log_group.performance.arn
}

# Dashboard Outputs
output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

# Alarm Outputs
output "cpu_alarm_names" {
  description = "Names of the CPU utilization alarms"
  value       = aws_cloudwatch_metric_alarm.high_cpu[*].alarm_name
}

output "instance_status_alarm_names" {
  description = "Names of the instance status check alarms"
  value       = aws_cloudwatch_metric_alarm.instance_status_check[*].alarm_name
}

output "system_status_alarm_names" {
  description = "Names of the system status check alarms"
  value       = aws_cloudwatch_metric_alarm.system_status_check[*].alarm_name
}

# Lambda Outputs (if Slack is enabled)
output "slack_notifier_function_name" {
  description = "Name of the Slack notifier Lambda function"
  value       = var.enable_slack_notifications ? aws_lambda_function.slack_notifier[0].function_name : null
}

output "slack_notifier_function_arn" {
  description = "ARN of the Slack notifier Lambda function"
  value       = var.enable_slack_notifications ? aws_lambda_function.slack_notifier[0].arn : null
}