# Production Environment Configuration
# This configuration is for production with high availability, security, and compliance requirements

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    # Configure your S3 backend here
    # bucket = "your-terraform-state-bucket"
    # key    = "prod/terraform.tfstate"
    # region = "us-west-2"
    # encrypt = true
    # dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "prod"
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Owner       = "DevOps"
      Compliance  = "Required"
    }
  }
}

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
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access resources"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "notification_email" {
  description = "Email for CloudWatch notifications"
  type        = string
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "min_size" {
  description = "Minimum number of instances in Auto Scaling Group"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances in Auto Scaling Group"
  type        = number
  default     = 10
}

variable "desired_capacity" {
  description = "Desired number of instances in Auto Scaling Group"
  type        = number
  default     = 3
}

# Local values for production environment
locals {
  environment = "prod"
  
  # Production-specific sizing
  instance_type = "m5.large"
  root_volume_size = 50
  
  # Production-specific network configuration (multi-AZ)
  vpc_cidr = "10.0.0.0/16"
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  database_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]
  
  # Production-specific features (high availability)
  single_nat_gateway = false
  enable_backup = true
  backup_retention_days = 30
  
  # Production-specific monitoring
  log_retention_days = 90
  enable_detailed_monitoring = true
  
  # Production-specific security (strict)
  enable_database_sg = true
  enable_alb_sg = true
  enable_management_sg = true
  
  common_tags = {
    Environment = local.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Owner       = "DevOps"
    CostCenter  = "Production"
    Compliance  = "SOC2"
    DataClass   = "Confidential"
  }
}

# Network Module
module "network" {
  source = "../../application/network"

  vpc_name                = "${var.project_name}-${local.environment}"
  vpc_cidr               = local.vpc_cidr
  availability_zones     = local.availability_zones
  public_subnet_cidrs    = local.public_subnet_cidrs
  private_subnet_cidrs   = local.private_subnet_cidrs
  database_subnet_cidrs  = local.database_subnet_cidrs
  
  enable_nat_gateway     = true
  single_nat_gateway     = local.single_nat_gateway
  enable_vpc_flow_logs   = true
  flow_log_retention_days = local.log_retention_days
  
  environment    = local.environment
  project_name   = var.project_name
  common_tags    = local.common_tags
}

# IAM Module
module "iam" {
  source = "../../application/iam"

  role_name              = "ec2-role"
  instance_profile_name  = "ec2-instance-profile"
  
  enable_ssm_access      = true
  enable_cloudwatch_agent = true
  enable_secrets_manager = true
  enable_s3_access      = true
  
  environment   = local.environment
  project_name  = var.project_name
  common_tags   = local.common_tags
}

# Security Module
module "security" {
  source = "../../application/security"

  vpc_id = module.network.vpc_id
  
  # Security Group Configuration
  app_ports              = [80, 443]
  allowed_cidr_blocks    = var.allowed_cidr_blocks
  db_port               = 3306
  
  enable_database_sg     = local.enable_database_sg
  enable_alb_sg         = local.enable_alb_sg
  enable_management_sg  = local.enable_management_sg
  management_allowed_cidrs = ["10.0.0.0/16"]
  
  # KMS Configuration
  enable_kms             = true
  kms_key_deletion_window = 30
  kms_key_rotation_enabled = true
  
  environment   = local.environment
  project_name  = var.project_name
  common_tags   = local.common_tags
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${local.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.security.alb_security_group_id]
  subnets           = module.network.public_subnet_ids

  enable_deletion_protection = true
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb-logs"
    enabled = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.environment}-alb"
  })
}

# S3 bucket for ALB logs
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.project_name}-${local.environment}-alb-logs-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${local.environment}-alb-logs"
    Purpose = "LoadBalancerLogs"
  })
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = module.security.kms_key_id
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

# Launch Template for Auto Scaling
resource "aws_launch_template" "main" {
  name_prefix   = "${var.project_name}-${local.environment}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = local.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [module.security.app_security_group_id]

  iam_instance_profile {
    name = module.iam.instance_profile_name
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = local.root_volume_size
      volume_type          = "gp3"
      encrypted            = true
      kms_key_id           = module.security.kms_key_id
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = local.enable_detailed_monitoring
  }

  user_data = base64encode(templatefile("${path.module}/../../application/ec2/user-data.sh", {
    cloudwatch_config = ""
    log_group_name    = "/aws/ec2/${var.project_name}/${local.environment}"
    region           = var.aws_region
    project_name     = var.project_name
    environment      = local.environment
    instance_name    = "web-server"
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${var.project_name}-${local.environment}-web-server"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "main" {
  name                = "${var.project_name}-${local.environment}-asg"
  vpc_zone_identifier = module.network.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.main.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${local.environment}-asg"
    propagate_at_launch = false
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Target Group
resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-${local.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.network.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.environment}-tg"
  })
}

# ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# Monitoring Module
module "monitoring" {
  source = "../../application/monitoring"

  # Production monitoring configuration
  log_retention_days       = local.log_retention_days
  enable_detailed_monitoring = local.enable_detailed_monitoring
  notification_email       = var.notification_email
  enable_slack_notifications = var.slack_webhook_url != ""
  slack_webhook_url        = var.slack_webhook_url
  
  # Alarm thresholds (strict for production)
  cpu_threshold_high    = 70
  memory_threshold_high = 75
  disk_threshold_high   = 80
  
  # Resources to monitor
  instance_ids        = []  # Will be populated by ASG instances
  load_balancer_arns  = [aws_lb.main.arn]
  
  environment  = local.environment
  project_name = var.project_name
  common_tags  = local.common_tags
}

# Data source for Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "auto_scaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.main.name
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.cloudwatch_dashboard_url
}