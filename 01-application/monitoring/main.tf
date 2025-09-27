# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-alerts"
    Environment = var.environment
    Purpose     = "Monitoring"
  })
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# Email Subscription (if email provided)
resource "aws_sns_topic_subscription" "email" {
  count = var.notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/application/${var.project_name}/${var.environment}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-app-logs"
    Environment = var.environment
    Purpose     = "ApplicationLogging"
  })
}

resource "aws_cloudwatch_log_group" "security" {
  name              = "/aws/security/${var.project_name}/${var.environment}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-security-logs"
    Environment = var.environment
    Purpose     = "SecurityLogging"
  })
}

resource "aws_cloudwatch_log_group" "performance" {
  name              = "/aws/performance/${var.project_name}/${var.environment}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-performance-logs"
    Environment = var.environment
    Purpose     = "PerformanceLogging"
  })
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", var.instance_ids[0]]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "EC2 CPU Utilization"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", var.instance_ids[0]],
            [".", "NetworkOut", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "EC2 Network Traffic"
          period  = 300
        }
      }
    ]
  })
}

# CloudWatch Alarms for EC2 Instances
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = length(var.instance_ids)

  alarm_name          = "${var.project_name}-${var.environment}-high-cpu-${count.index}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_threshold_high
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = var.instance_ids[count.index]
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-high-cpu-${count.index}"
    Environment = var.environment
    Purpose     = "Monitoring"
  })
}

resource "aws_cloudwatch_metric_alarm" "instance_status_check" {
  count = length(var.instance_ids)

  alarm_name          = "${var.project_name}-${var.environment}-instance-status-${count.index}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed_Instance"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "This metric monitors ec2 instance status check"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = var.instance_ids[count.index]
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-instance-status-${count.index}"
    Environment = var.environment
    Purpose     = "Monitoring"
  })
}

resource "aws_cloudwatch_metric_alarm" "system_status_check" {
  count = length(var.instance_ids)

  alarm_name          = "${var.project_name}-${var.environment}-system-status-${count.index}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed_System"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "This metric monitors ec2 system status check"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = var.instance_ids[count.index]
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-system-status-${count.index}"
    Environment = var.environment
    Purpose     = "Monitoring"
  })
}

# CloudWatch Alarms for Load Balancers
resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  count = length(var.load_balancer_arns)

  alarm_name          = "${var.project_name}-${var.environment}-alb-response-time-${count.index}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "This metric monitors ALB target response time"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = element(split("/", var.load_balancer_arns[count.index]), length(split("/", var.load_balancer_arns[count.index])) - 1)
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-alb-response-time-${count.index}"
    Environment = var.environment
    Purpose     = "Monitoring"
  })
}

resource "aws_cloudwatch_metric_alarm" "alb_healthy_hosts" {
  count = length(var.load_balancer_arns)

  alarm_name          = "${var.project_name}-${var.environment}-alb-healthy-hosts-${count.index}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors ALB healthy host count"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = element(split("/", var.load_balancer_arns[count.index]), length(split("/", var.load_balancer_arns[count.index])) - 1)
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-alb-healthy-hosts-${count.index}"
    Environment = var.environment
    Purpose     = "Monitoring"
  })
}

# Lambda function for Slack notifications (if enabled)
resource "aws_lambda_function" "slack_notifier" {
  count = var.enable_slack_notifications ? 1 : 0

  filename         = "slack_notifier.zip"
  function_name    = "${var.project_name}-${var.environment}-slack-notifier"
  role            = aws_iam_role.lambda_role[0].arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.slack_notifier[0].output_base64sha256
  runtime         = "python3.9"
  timeout         = 60

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-slack-notifier"
    Environment = var.environment
    Purpose     = "Monitoring"
  })
}

# Lambda function code for Slack notifications
data "archive_file" "slack_notifier" {
  count = var.enable_slack_notifications ? 1 : 0

  type        = "zip"
  output_path = "slack_notifier.zip"
  source {
    content = templatefile("${path.module}/slack_notifier.py", {
      webhook_url = var.slack_webhook_url
    })
    filename = "index.py"
  }
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  count = var.enable_slack_notifications ? 1 : 0

  name = "${var.project_name}-${var.environment}-lambda-slack-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-lambda-slack-role"
    Environment = var.environment
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  count = var.enable_slack_notifications ? 1 : 0

  role       = aws_iam_role.lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# SNS subscription for Lambda
resource "aws_sns_topic_subscription" "lambda" {
  count = var.enable_slack_notifications ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier[0].arn
}

resource "aws_lambda_permission" "allow_sns" {
  count = var.enable_slack_notifications ? 1 : 0

  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}