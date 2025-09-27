# ================================
# Enterprise Base Module Main Configuration
# ================================
# This module provides a complete enterprise infrastructure stack
# that can be consumed by environment-specific configurations

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


# ================================
# Local Values for Environment-Specific Configuration
# ================================

locals {
  # Environment-specific configurations
  env_config = {
    dev = {
      instance_type           = "t3.small"
      root_volume_size       = 20
      vpc_cidr              = "10.0.0.0/16"
      availability_zones    = ["${var.aws_region}a", "${var.aws_region}b"]
      public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
      private_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24"]
      database_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24"]
      single_nat_gateway    = true
      enable_backup         = false
      backup_retention_days = 3
      log_retention_days    = 7
      enable_detailed_monitoring = false
    }
    staging = {
      instance_type           = "t3.medium"
      root_volume_size       = 30
      vpc_cidr              = "10.1.0.0/16"
      availability_zones    = ["${var.aws_region}a", "${var.aws_region}b"]
      public_subnet_cidrs   = ["10.1.1.0/24", "10.1.2.0/24"]
      private_subnet_cidrs  = ["10.1.10.0/24", "10.1.11.0/24"]
      database_subnet_cidrs = ["10.1.20.0/24", "10.1.21.0/24"]
      single_nat_gateway    = true
      enable_backup         = true
      backup_retention_days = 14
      log_retention_days    = 30
      enable_detailed_monitoring = true
    }
    prod = {
      instance_type           = "m5.large"
      root_volume_size       = 50
      vpc_cidr              = "10.0.0.0/16"
      availability_zones    = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
      public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
      private_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
      database_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]
      single_nat_gateway    = false
      enable_backup         = true
      backup_retention_days = 30
      log_retention_days    = 90
      enable_detailed_monitoring = true
    }
  }

  # Current environment configuration
  current_config = local.env_config[var.environment]

  # Common tags
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Owner       = "DevOps"
    CostCenter  = title(var.environment)
  }
}

# ================================
# Provider Configuration
# ================================

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = local.common_tags
  }
}

# ================================
# Data Sources
# ================================

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

# ================================
# Network Module
# ================================

module "network" {
  source = "../01-application/network"

  vpc_name                = "${var.project_name}-${var.environment}"
  vpc_cidr               = local.current_config.vpc_cidr
  availability_zones     = local.current_config.availability_zones
  public_subnet_cidrs    = local.current_config.public_subnet_cidrs
  private_subnet_cidrs   = local.current_config.private_subnet_cidrs
  database_subnet_cidrs  = local.current_config.database_subnet_cidrs
  
  enable_nat_gateway     = true
  single_nat_gateway     = local.current_config.single_nat_gateway
  enable_vpc_flow_logs   = true
  flow_log_retention_days = local.current_config.log_retention_days
  
  environment    = var.environment
  project_name   = var.project_name
  common_tags    = local.common_tags
}

# ================================
# IAM Module
# ================================

module "iam" {
  source = "../01-application/iam"

  role_name              = "ec2-role"
  instance_profile_name  = "ec2-instance-profile"
  
  enable_ssm_access      = true
  enable_cloudwatch_agent = true
  enable_secrets_manager = true
  enable_s3_access      = true
  
  environment   = var.environment
  project_name  = var.project_name
  common_tags   = local.common_tags
}

# ================================
# Security Module
# ================================

module "security" {
  source = "../01-application/security"

  vpc_id = module.network.vpc_id
  
  # Security Group Configuration
  app_ports              = [80, 443, 8080]
  allowed_cidr_blocks    = var.allowed_cidr_blocks
  db_port               = 3306
  
  enable_database_sg     = true
  enable_alb_sg         = true
  enable_management_sg  = true
  management_allowed_cidrs = [local.current_config.vpc_cidr]
  
  # KMS Configuration
  enable_kms             = true
  kms_key_deletion_window = var.environment == "prod" ? 30 : 7
  kms_key_rotation_enabled = var.environment == "prod" ? true : false
  
  environment   = var.environment
  project_name  = var.project_name
  common_tags   = local.common_tags
}

# ================================
# EC2 Instances (Multiple instances or Auto Scaling based on configuration)
# ================================

# Multiple EC2 instances (when auto scaling is disabled)
module "ec2_instances" {
  source = "../01-application/ec2"
  count  = var.enable_auto_scaling ? 0 : var.instance_count

  # Instance Configuration
  instance_type = local.current_config.instance_type
  ami_id        = data.aws_ami.amazon_linux.id
  name          = "web-server-${count.index + 1}"
  
  # Network Configuration
  subnet_id                   = module.network.private_subnet_ids[count.index % length(module.network.private_subnet_ids)]
  vpc_id                     = module.network.vpc_id
  security_group_ids         = [module.security.app_security_group_id]
  associate_public_ip_address = false
  availability_zone          = local.current_config.availability_zones[count.index % length(local.current_config.availability_zones)]
  
  # IAM Configuration
  iam_instance_profile_name = module.iam.instance_profile_name
  
  # Storage Configuration
  root_volume_size      = local.current_config.root_volume_size
  root_volume_type      = "gp3"
  root_volume_encrypted = true
  kms_key_id           = module.security.kms_key_id
  
  # Security Configuration
  key_name                = var.key_name
  disable_api_termination = var.environment == "prod" ? true : false
  
  # Teaching Variable Wiring - Pass instance_count_string to EC2 module
  instance_count_string = var.instance_count_string
  
  # Monitoring Configuration
  enable_detailed_monitoring = local.current_config.enable_detailed_monitoring
  enable_cloudwatch_agent   = true
  
  # Backup Configuration
  enable_backup         = local.current_config.enable_backup
  backup_retention_days = local.current_config.backup_retention_days
  
  environment   = var.environment
  project_name  = var.project_name
  common_tags   = local.common_tags
}

# ================================
# Auto Scaling Configuration (for production environments)
# ================================

# Launch Template for Auto Scaling
resource "aws_launch_template" "main" {
  count = var.enable_auto_scaling ? 1 : 0

  name_prefix   = "${var.project_name}-${var.environment}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = local.current_config.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [module.security.app_security_group_id]

  iam_instance_profile {
    name = module.iam.instance_profile_name
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = local.current_config.root_volume_size
      volume_type          = "gp3"
      encrypted            = true
      kms_key_id           = module.security.kms_key_id
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = local.current_config.enable_detailed_monitoring
  }

  user_data = base64encode(templatefile("${path.module}/../01-application/ec2/user-data.sh", {
    cloudwatch_config = ""
    log_group_name    = "/aws/ec2/${var.project_name}/${var.environment}"
    region           = var.aws_region
    project_name     = var.project_name
    environment      = var.environment
    instance_name    = "web-server"
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${var.project_name}-${var.environment}-web-server"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "main" {
  count = var.enable_auto_scaling ? 1 : 0

  name                = "${var.project_name}-${var.environment}-asg"
  vpc_zone_identifier = module.network.private_subnet_ids
  health_check_type   = "EC2"
  health_check_grace_period = 300

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  launch_template {
    id      = aws_launch_template.main[0].id
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
    value               = "${var.project_name}-${var.environment}-asg"
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

# ================================
# Monitoring Module
# ================================

module "monitoring" {
  source = "../01-application/monitoring"

  # Monitoring configuration
  log_retention_days       = local.current_config.log_retention_days
  enable_detailed_monitoring = local.current_config.enable_detailed_monitoring
  notification_email       = var.notification_email
  
  # Alarm thresholds based on environment
  cpu_threshold_high    = var.environment == "prod" ? 70 : (var.environment == "staging" ? 80 : 90)
  memory_threshold_high = var.environment == "prod" ? 75 : (var.environment == "staging" ? 80 : 90)
  disk_threshold_high   = var.environment == "prod" ? 80 : (var.environment == "staging" ? 85 : 95)
  
  # Resources to monitor
  instance_ids = var.enable_auto_scaling ? [] : [for instance in module.ec2_instances : instance.instance_id]
  
  environment  = var.environment
  project_name = var.project_name
  common_tags  = local.common_tags
}
