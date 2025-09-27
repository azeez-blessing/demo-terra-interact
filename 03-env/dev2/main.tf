# Staging Environment Configuration
# This configuration is for staging/testing with production-like setup but reduced costs

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
    # key    = "staging/terraform.tfstate"
    # region = "us-west-2"
    # encrypt = true
    # dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "staging"
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Owner       = "DevOps"
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
  default     = null
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access resources"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "notification_email" {
  description = "Email for CloudWatch notifications"
  type        = string
  default     = ""
}

# Local values for staging environment
locals {
  environment = "staging"
  
  # Staging-specific sizing (between dev and prod)
  instance_type = "t3.medium"
  root_volume_size = 30
  
  # Staging-specific network configuration
  vpc_cidr = "10.1.0.0/16"
  availability_zones = ["us-west-2a", "us-west-2b"]
  public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
  database_subnet_cidrs = ["10.1.20.0/24", "10.1.21.0/24"]
  
  # Staging-specific features (balance between cost and availability)
  single_nat_gateway = true
  enable_backup = true
  backup_retention_days = 14
  
  # Staging-specific monitoring
  log_retention_days = 30
  enable_detailed_monitoring = true
  
  # Staging-specific security
  enable_database_sg = true
  enable_alb_sg = true
  enable_management_sg = true
  
  common_tags = {
    Environment = local.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Owner       = "DevOps"
    CostCenter  = "Testing"
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
  app_ports              = [80, 443, 8080]
  allowed_cidr_blocks    = var.allowed_cidr_blocks
  db_port               = 3306
  
  enable_database_sg     = local.enable_database_sg
  enable_alb_sg         = local.enable_alb_sg
  enable_management_sg  = local.enable_management_sg
  management_allowed_cidrs = ["10.1.0.0/16"]
  
  # KMS Configuration
  enable_kms             = true
  kms_key_deletion_window = 7
  kms_key_rotation_enabled = true
  
  environment   = local.environment
  project_name  = var.project_name
  common_tags   = local.common_tags
}

# EC2 Instances (2 for high availability testing)
module "web_server_1" {
  source = "../../application/ec2"

  # Instance Configuration
  instance_type = local.instance_type
  ami_id        = data.aws_ami.amazon_linux.id
  name          = "web-server-1"
  
  # Network Configuration
  subnet_id                   = module.network.private_subnet_ids[0]
  vpc_id                     = module.network.vpc_id
  security_group_ids         = [module.security.app_security_group_id]
  associate_public_ip_address = false
  availability_zone          = local.availability_zones[0]
  
  # IAM Configuration
  iam_instance_profile_name = module.iam.instance_profile_name
  
  # Storage Configuration
  root_volume_size      = local.root_volume_size
  root_volume_type      = "gp3"
  root_volume_encrypted = true
  kms_key_id           = module.security.kms_key_id
  
  # Security Configuration
  key_name                = var.key_name
  disable_api_termination = true
  
  # Monitoring Configuration
  enable_detailed_monitoring = local.enable_detailed_monitoring
  enable_cloudwatch_agent   = true
  
  # Backup Configuration
  enable_backup         = local.enable_backup
  backup_retention_days = local.backup_retention_days
  
  environment   = local.environment
  project_name  = var.project_name
  common_tags   = local.common_tags
}

module "web_server_2" {
  source = "../../application/ec2"

  # Instance Configuration
  instance_type = local.instance_type
  ami_id        = data.aws_ami.amazon_linux.id
  name          = "web-server-2"
  
  # Network Configuration
  subnet_id                   = module.network.private_subnet_ids[1]
  vpc_id                     = module.network.vpc_id
  security_group_ids         = [module.security.app_security_group_id]
  associate_public_ip_address = false
  availability_zone          = local.availability_zones[1]
  
  # IAM Configuration
  iam_instance_profile_name = module.iam.instance_profile_name
  
  # Storage Configuration
  root_volume_size      = local.root_volume_size
  root_volume_type      = "gp3"
  root_volume_encrypted = true
  kms_key_id           = module.security.kms_key_id
  
  # Security Configuration
  key_name                = var.key_name
  disable_api_termination = true
  
  # Monitoring Configuration
  enable_detailed_monitoring = local.enable_detailed_monitoring
  enable_cloudwatch_agent   = true
  
  # Backup Configuration
  enable_backup         = local.enable_backup
  backup_retention_days = local.backup_retention_days
  
  environment   = local.environment
  project_name  = var.project_name
  common_tags   = local.common_tags
}

# Monitoring Module
module "monitoring" {
  source = "../../application/monitoring"

  # Staging monitoring configuration
  log_retention_days       = local.log_retention_days
  enable_detailed_monitoring = local.enable_detailed_monitoring
  notification_email       = var.notification_email
  
  # Alarm thresholds (moderate for staging)
  cpu_threshold_high    = 80
  memory_threshold_high = 80
  disk_threshold_high   = 85
  
  # Resources to monitor
  instance_ids = [
    module.web_server_1.instance_id,
    module.web_server_2.instance_id
  ]
  
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

output "instance_ids" {
  description = "IDs of the EC2 instances"
  value = [
    module.web_server_1.instance_id,
    module.web_server_2.instance_id
  ]
}

output "instance_private_ips" {
  description = "Private IPs of the EC2 instances"
  value = [
    module.web_server_1.instance_private_ip,
    module.web_server_2.instance_private_ip
  ]
}

output "ssh_connection_commands" {
  description = "SSH connection commands"
  value = [
    module.web_server_1.ssh_connection_command,
    module.web_server_2.ssh_connection_command
  ]
}

output "ssm_connection_commands" {
  description = "AWS Systems Manager Session Manager connection commands"
  value = [
    module.web_server_1.ssm_connection_command,
    module.web_server_2.ssm_connection_command
  ]
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.cloudwatch_dashboard_url
}