# CloudWatch Log Group for instance logs
resource "aws_cloudwatch_log_group" "instance_logs" {
  count = var.enable_cloudwatch_agent ? 1 : 0

  name              = coalesce(var.cloudwatch_log_group_name, "/aws/ec2/${var.project_name}/${var.environment}/${var.name}")
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${var.name}-logs"
    Environment = var.environment
    Instance    = var.name
  })
}

# User data script for CloudWatch agent and SSM
locals {
  cloudwatch_config = var.enable_cloudwatch_agent ? jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "cwagent"
    }
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path      = "/var/log/messages"
              log_group_name = var.enable_cloudwatch_agent ? aws_cloudwatch_log_group.instance_logs[0].name : ""
              log_stream_name = "{instance_id}/var/log/messages"
              retention_in_days = 30
            },
            {
              file_path      = "/var/log/secure"
              log_group_name = var.enable_cloudwatch_agent ? aws_cloudwatch_log_group.instance_logs[0].name : ""
              log_stream_name = "{instance_id}/var/log/secure"
              retention_in_days = 30
            }
          ]
        }
      }
    }
    metrics = {
      namespace = "${var.project_name}/${var.environment}/EC2"
      metrics_collected = {
        cpu = {
          measurement = ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"]
          metrics_collection_interval = 60
        }
        disk = {
          measurement = ["used_percent"]
          metrics_collection_interval = 60
          resources = ["*"]
        }
        diskio = {
          measurement = ["io_time", "read_bytes", "write_bytes", "reads", "writes"]
          metrics_collection_interval = 60
          resources = ["*"]
        }
        mem = {
          measurement = ["mem_used_percent"]
          metrics_collection_interval = 60
        }
        netstat = {
          measurement = ["tcp_established", "tcp_time_wait"]
          metrics_collection_interval = 60
        }
      }
    }
  }) : ""

  default_user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    cloudwatch_config = local.cloudwatch_config
    log_group_name    = var.enable_cloudwatch_agent ? aws_cloudwatch_log_group.instance_logs[0].name : ""
    region           = data.aws_region.current.name
    project_name     = var.project_name
    environment      = var.environment
    instance_name    = var.name
  }))

  user_data = coalesce(var.user_data_base64, local.default_user_data)
}

# EC2 Instance
resource "aws_instance" "this" {
  ami                     = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = var.iam_instance_profile_name
  
  associate_public_ip_address = var.associate_public_ip_address
  source_dest_check          = var.source_dest_check
  disable_api_termination    = var.disable_api_termination
  disable_api_stop           = var.disable_api_stop
  
  availability_zone = var.availability_zone
  placement_group   = var.placement_group
  tenancy          = var.tenancy
  
  monitoring = var.enable_detailed_monitoring
  
  user_data_base64                = local.user_data
  user_data_replace_on_change     = var.user_data_replace_on_change

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    encrypted            = var.root_volume_encrypted
    kms_key_id           = var.kms_key_id
    delete_on_termination = true

    tags = merge(var.common_tags, var.instance_tags, {
      Name        = "${var.project_name}-${var.environment}-${var.name}-root"
      Environment = var.environment
      Instance    = var.name
      VolumeType  = "Root"
    })
  }

  dynamic "ebs_block_device" {
    for_each = var.additional_ebs_volumes
    content {
      device_name           = ebs_block_device.value.device_name
      volume_type          = ebs_block_device.value.volume_type
      volume_size          = ebs_block_device.value.volume_size
      encrypted            = ebs_block_device.value.encrypted
      kms_key_id           = var.kms_key_id
      iops                 = ebs_block_device.value.iops
      throughput           = ebs_block_device.value.throughput
      delete_on_termination = true

      tags = merge(var.common_tags, var.instance_tags, {
        Name        = "${var.project_name}-${var.environment}-${var.name}-${ebs_block_device.value.device_name}"
        Environment = var.environment
        Instance    = var.name
        VolumeType  = "Additional"
      })
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      ami, # Prevent recreation when AMI is updated
    ]
  }

  tags = merge(var.common_tags, var.instance_tags, {
    Name         = "${var.project_name}-${var.environment}-${var.name}"
    Environment  = var.environment
    InstanceName = var.name
    Project      = var.project_name
    Backup       = var.enable_backup ? "true" : "false"
    MaintenanceWindow = var.maintenance_window
  })
}

# AWS Backup Plan (if enabled)
resource "aws_backup_vault" "main" {
  count = var.enable_backup ? 1 : 0

  name        = "${var.project_name}-${var.environment}-backup-vault"
  kms_key_arn = var.kms_key_id

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-backup-vault"
    Environment = var.environment
  })
}

resource "aws_backup_plan" "main" {
  count = var.enable_backup ? 1 : 0

  name = "${var.project_name}-${var.environment}-backup-plan"

  rule {
    rule_name         = "daily_backups"
    target_vault_name = aws_backup_vault.main[0].name
    schedule          = "cron(0 5 ? * * *)" # Daily at 5 AM UTC

    lifecycle {
      cold_storage_after = 30
      delete_after       = var.backup_retention_days
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.main[0].arn
    }
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-backup-plan"
    Environment = var.environment
  })
}

resource "aws_iam_role" "backup_role" {
  count = var.enable_backup ? 1 : 0

  name = "${var.project_name}-${var.environment}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-backup-role"
    Environment = var.environment
  })
}

resource "aws_iam_role_policy_attachment" "backup_service_role" {
  count = var.enable_backup ? 1 : 0

  role       = aws_iam_role.backup_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_selection" "main" {
  count = var.enable_backup ? 1 : 0

  iam_role_arn = aws_iam_role.backup_role[0].arn
  name         = "${var.project_name}-${var.environment}-backup-selection"
  plan_id      = aws_backup_plan.main[0].id

  resources = [
    aws_instance.this.arn
  ]

  condition {
    string_equals {
      key   = "aws:ResourceTag/Backup"
      value = "true"
    }
  }
}