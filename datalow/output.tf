# =====================================
# OUTPUTS - Component Information
# =====================================
output "component_relationships" {
  description = "Shows how all components are connected"
  value = {
    step_1_cloudtrail = {
      resource = aws_cloudtrail.main_trail.arn
      action   = "Generates AWS API logs"
      output   = "Writes compressed JSON files to S3"
    }
    step_2_s3_storage = {
      resource = aws_s3_bucket.cloudtrail_logs.arn
      action   = "Stores CloudTrail log files"
      output   = "Triggers Lambda on new file creation"
    }
    step_3_s3_notification = {
      resource = "S3 Event Notification"
      action   = "Detects new .json.gz files in AWSLogs/ prefix"
      output   = "Invokes Lambda processor function"
    }
    step_4_lambda_processor = {
      resource = aws_lambda_function.cloudtrail_processor.arn
      action   = "Downloads, decompresses, and transforms logs"
      output   = "Sends individual events to Kinesis Firehose"
    }
    step_5_firehose_delivery = {
      resource = aws_kinesis_firehose_delivery_stream.cloudtrail_to_splunk.arn
      action   = "Buffers events and delivers to Splunk HEC"
      output   = "Structured logs appear in Splunk"
    }
    step_6_backup_storage = {
      resource = aws_s3_bucket.firehose_backup.arn
      action   = "Stores failed delivery events"
      output   = "Backup location for troubleshooting"
    }
  }
}

output "splunk_search_queries" {
  description = "Splunk queries to verify log delivery"
  value = {
    all_cloudtrail_events = "index=main sourcetype=\"aws:cloudtrail\" | head 100"
    recent_api_calls      = "index=main sourcetype=\"aws:cloudtrail\" | eval event_time=strftime(_time, \"%Y-%m-%d %H:%M:%S\") | table event_time, eventName, sourceIPAddress, userIdentity.type | head 20"
    error_events         = "index=main sourcetype=\"aws:cloudtrail\" errorCode=* | table _time, eventName, errorCode, errorMessage"
    user_activity        = "index=main sourcetype=\"aws:cloudtrail\" | stats count by userIdentity.type, eventName | sort -count"
  }
}

output "monitoring_resources" {
  description = "Resources to monitor the delivery pipeline"
  value = {
    cloudtrail_arn      = aws_cloudtrail.main_trail.arn
    s3_bucket           = aws_s3_bucket.cloudtrail_logs.id
    lambda_function     = aws_lambda_function.cloudtrail_processor.function_name
    firehose_stream     = aws_kinesis_firehose_delivery_stream.cloudtrail_to_splunk.name
    lambda_logs         = aws_cloudwatch_log_group.lambda_logs.name
    firehose_logs       = aws_cloudwatch_log_group.firehose_logs.name
  }
}