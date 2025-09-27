# This is where CloudTrail writes its log files

# bucket for storing and backing up CloudTrail logs
# cloud trail it self
# lambda function to process the logs
# bucket
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = var.cloudtrail_bucket_name
  force_destroy = true

  tags = {
    Name      = "${var.project_name}-cloudtrail-bucket"
    Component = "Storage"
    Purpose   = "CloudTrail log storage"
  }
}
# aws_s3_bucket  ===>bucket.id ======>aws_s3_bucket_versioning

# S3 bucket configuration
#S3 bucket versioning is a feature that allows Amazon S3 to keep multiple versions of an object
resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}



resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket                  = aws_s3_bucket.cloudtrail_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy - Allows CloudTrail to write logs
resource "aws_s3_bucket_policy" "cloudtrail_logs_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck20150319"
        Effect = "Allow"
        Principal = { #Principal:  The entity that is allowed or denied access to a resource.
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn # service that principal can access
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${var.project_name}-trail"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite20150319"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "AWS:SourceArn" = "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${var.project_name}-trail"
          }
        }
      }
    ]
  })
}









# =====================================
# COMPONENT 2: CLOUDTRAIL (Log Generator) from API event or Http verb
# =====================================
# This generates AWS API logs and writes them to S3
# param:name, s3_bucket_name
resource "aws_cloudtrail" "main_trail" {
  name           = "${var.project_name}-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail_logs.id
  
  # Enable logging for all supported events
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_logging               = true

  # Event selectors - what to log
  event_selector {
    read_write_type           = "All"  # ReadOnly, WriteOnly, or All
    include_management_events = true   # API calls like CreateInstance, DeleteBucket

    # Log data events for S3 (optional - generates more logs)
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/*"]
    }
    
    # Log data events for Lambda (optional)
    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda:*:*:function:*"]
    }
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs_policy]

  tags = {
    Name      = "${var.project_name}-cloudtrail"
    Component = "LogGenerator"
    Purpose   = "Generate AWS API audit logs"
  }
}

# =====================================
# COMPONENT 3: S3 BACKUP BUCKET (Firehose Backup)
# =====================================
# Firehose needs a backup location for failed deliveries
resource "aws_s3_bucket" "firehose_backup" {
  bucket        = "${var.cloudtrail_bucket_name}-backup"
  force_destroy = true

  tags = {
    Name      = "${var.project_name}-firehose-backup"
    Component = "Backup"
    Purpose   = "Store failed Splunk deliveries"
  }
}

resource "aws_s3_bucket_versioning" "firehose_backup" {
  bucket = aws_s3_bucket.firehose_backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "firehose_backup" {
  bucket = aws_s3_bucket.firehose_backup.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# =====================================
# COMPONENT 4: IAM ROLES (Security & Permissions)
# =====================================

# IAM Role for Lambda function to access S3 and Firehose
resource "aws_iam_role" "cloudtrail_processor_lambda_role" {
  name = "${var.project_name}-lambda-role"

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

  tags = {
    Name      = "${var.project_name}-lambda-role"
    Component = "Security"
    Purpose   = "Lambda execution permissions"
  }
}

# Lambda execution policy
resource "aws_iam_role_policy" "lambda_cloudtrail_processor_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.cloudtrail_processor_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # CloudWatch Logs permissions
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        # S3 read permissions for CloudTrail logs
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/*"
      },
      {
        # Firehose write permissions
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = aws_kinesis_firehose_delivery_stream.cloudtrail_to_splunk.arn
      }
    ]
  })
}

# IAM Role for Firehose to access S3 backup bucket
resource "aws_iam_role" "firehose_delivery_role" {
  name = "${var.project_name}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-firehose-role"
    Component = "Security"
    Purpose   = "Firehose delivery permissions"
  }
}

# Firehose permissions policy
resource "aws_iam_role_policy" "firehose_delivery_policy" {
  name = "${var.project_name}-firehose-policy"
  role = aws_iam_role.firehose_delivery_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # S3 backup bucket permissions
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.firehose_backup.arn,
          "${aws_s3_bucket.firehose_backup.arn}/*"
        ]
      },
      {
        # CloudWatch Logs permissions for Firehose logging
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}











# CloudTrail ----generate log and send it to--------> s3 ---> (Notification) ---------put event trigger---------> lambda function ---------> firehose ---------> splunk





# Lambda function
#params: filename, function_name, role
resource "aws_lambda_function" "cloudtrail_processor" {
  filename         = data.archive_file.cloudtrail_processor_zip.output_path
  function_name    = "${var.project_name}-cloudtrail-processor"
  role            = aws_iam_role.cloudtrail_processor_lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300
  memory_size     = 512

  # Environment variables
  environment {
    variables = {
      FIREHOSE_STREAM_NAME = aws_kinesis_firehose_delivery_stream.cloudtrail_to_splunk.name
      SPLUNK_SOURCE        = "aws:cloudtrail"
      SPLUNK_SOURCETYPE    = "aws:cloudtrail"
    }
  }

  depends_on = [data.archive_file.cloudtrail_processor_zip]

  tags = {
    Name      = "${var.project_name}-processor"
    Component = "LogProcessor"
    Purpose   = "Transform CloudTrail logs for Splunk"
  }
}

# Lambda permission for S3 to invoke the function
resource "aws_lambda_permission" "s3_invoke_lambda" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloudtrail_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.cloudtrail_logs.arn
}

# =====================================
# COMPONENT 6: S3 EVENT NOTIFICATION (Trigger)
# =====================================
# This connects S3 bucket to Lambda function
# this is where s3 trigger the lambda function


# aws_s3_bucket =======>bucket.id ======>aws_s3_bucket_notification
#param: bucket, lambda_function_arn
resource "aws_s3_bucket_notification" "cloudtrail_notification" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.cloudtrail_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "AWSLogs/"
    filter_suffix       = ".json.gz"
  }

  depends_on = [aws_lambda_permission.s3_invoke_lambda]
}

# =====================================
# COMPONENT 7: KINESIS DATA FIREHOSE (Delivery Stream)
# =====================================
# This delivers processed logs to Splunk

# aws_kinesis_firehose_delivery_stream ======hec_url, hec_token============> splunk
#param: name, destination,
resource "aws_kinesis_firehose_delivery_stream" "cloudtrail_to_splunk" {
  name        = "${var.project_name}-to-splunk"
  destination = "splunk"

  splunk_configuration {
    # Splunk HEC endpoint and authentication
    hec_endpoint               = var.splunk_hec_endpoint
    hec_token                 = var.splunk_hec_token
    hec_acknowledgment_timeout = 180
    hec_endpoint_type         = "Event"
    
    # Retry and backup configuration
    retry_duration    = 3600  # 1 hour retry
    s3_backup_mode   = "FailedEventsOnly"

    # Buffering settings for efficiency
    buffering_size     = 5    # MB
    buffering_interval = 60   # seconds

    # S3 backup configuration for failed events
    s3_configuration {
      role_arn           = aws_iam_role.firehose_delivery_role.arn
      bucket_arn         = aws_s3_bucket.firehose_backup.arn
      prefix             = "failed-events/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
      error_output_prefix = "errors/"
      buffering_size      = 64
      buffering_interval  = 300
      compression_format  = "GZIP"
    }

    # CloudWatch logging for monitoring kinesis firehose
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/${var.project_name}-delivery" # relate to aws_cloudwatch_log_group
    }
  }

  tags = {
    Name      = "${var.project_name}-firehose"
    Component = "DeliveryStream"
    Purpose   = "Stream CloudTrail logs to Splunk"
  }
}

# CloudWatch log group for Firehose

# aws_cloudwatch_log_group  ====aws_kinesis_firehose_delivery_stream cloudwatch_logging_options=============> kinesis firehose
resource "aws_cloudwatch_log_group" "firehose_logs" {
  name              = "/aws/kinesisfirehose/${var.project_name}-delivery"
  retention_in_days = 7

  tags = {
    Name      = "${var.project_name}-firehose-logs"
    Component = "Monitoring"
    Purpose   = "Firehose delivery monitoring"
  }
}

# CloudWatch log group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.cloudtrail_processor.function_name}"
  retention_in_days = 7

  tags = {
    Name      = "${var.project_name}-lambda-logs"
    Component = "Monitoring"  
    Purpose   = "Lambda function monitoring"
  }
}

