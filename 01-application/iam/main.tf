# IAM Role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-${var.role_name}"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${var.role_name}"
    Environment = var.environment
    Purpose     = "EC2InstanceRole"
  })
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-${var.instance_profile_name}"
  role = aws_iam_role.ec2_role.name

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${var.instance_profile_name}"
    Environment = var.environment
  })
}

# AWS Systems Manager Policy Attachment
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  count = var.enable_ssm_access ? 1 : 0

  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Agent Policy Attachment
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server_policy" {
  count = var.enable_cloudwatch_agent ? 1 : 0

  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Custom policy for enhanced SSM access
resource "aws_iam_role_policy" "enhanced_ssm_policy" {
  count = var.enable_ssm_access ? 1 : 0

  name = "${var.project_name}-${var.environment}-enhanced-ssm-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssm:SendCommand",
          "ssm:ListCommands",
          "ssm:ListCommandInvocations",
          "ssm:DescribeInstanceInformation",
          "ssm:GetConnectionStatus",
          "ssm:DescribeInstanceAssociationsStatus",
          "ssm:GetManifest",
          "ssm:GetDocument",
          "ssm:DescribeDocument",
          "ssm:ListDocuments",
          "ssm:UpdateAssociationStatus",
          "ssm:UpdateInstanceAssociationStatus",
          "ec2:DescribeInstanceAttribute",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# Secrets Manager Access Policy
resource "aws_iam_role_policy" "secrets_manager_policy" {
  count = var.enable_secrets_manager ? 1 : 0

  name = "${var.project_name}-${var.environment}-secrets-manager-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:*:*:secret:${var.project_name}/${var.environment}/*"
        ]
      }
    ]
  })
}

# S3 Access Policy
resource "aws_iam_role_policy" "s3_access_policy" {
  count = var.enable_s3_access && length(var.s3_bucket_arns) > 0 ? 1 : 0

  name = "${var.project_name}-${var.environment}-s3-access-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = concat(
          var.s3_bucket_arns,
          [for arn in var.s3_bucket_arns : "${arn}/*"]
        )
      }
    ]
  })
}

# Default S3 logging policy (if no specific buckets provided)
resource "aws_iam_role_policy" "default_s3_logging_policy" {
  count = var.enable_s3_access && length(var.s3_bucket_arns) == 0 ? 1 : 0

  name = "${var.project_name}-${var.environment}-default-s3-logging-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-logs/*",
          "arn:aws:s3:::${var.project_name}-${var.environment}-logs",
          "arn:aws:s3:::${var.project_name}-${var.environment}-artifacts/*",
          "arn:aws:s3:::${var.project_name}-${var.environment}-artifacts"
        ]
      }
    ]
  })
}

# CloudWatch Logs Policy
resource "aws_iam_role_policy" "cloudwatch_logs_policy" {
  count = var.enable_cloudwatch_agent ? 1 : 0

  name = "${var.project_name}-${var.environment}-cloudwatch-logs-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:*:*:log-group:/aws/ec2/${var.project_name}/${var.environment}/*",
          "arn:aws:logs:*:*:log-group:/aws/ec2/${var.project_name}/${var.environment}"
        ]
      }
    ]
  })
}

# EC2 Instance Connect Policy
resource "aws_iam_role_policy" "ec2_instance_connect_policy" {
  name = "${var.project_name}-${var.environment}-ec2-instance-connect-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2-instance-connect:SendSSHPublicKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:osuser" = ["ec2-user", "ubuntu", "admin"]
          }
        }
      }
    ]
  })
}

# Attach custom policies
resource "aws_iam_role_policy_attachment" "custom_policies" {
  count = length(var.custom_policies)

  role       = aws_iam_role.ec2_role.name
  policy_arn = var.custom_policies[count.index]
}