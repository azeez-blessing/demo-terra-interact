# Component relationship diagram in comments
/*
CLOUDTRAIL LOG DELIVERY FLOW:

┌─────────────────┐
│   AWS API Call │ (User creates EC2 instance, deletes S3 object, etc.)
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│   CloudTrail    │ (Captures API call details)
│      Trail      │ 
└─────────┬───────┘
          │ Writes compressed JSON file
          │ Format: AWSLogs/123456789012/CloudTrail/us-east-1/2024/01/15/file.json.gz
          ▼
┌─────────────────┐
│   S3 Bucket     │ (Stores CloudTrail logs)
│ cloudtrail_logs │ 
└─────────┬───────┘
          │ S3 Event: s3:ObjectCreated:*
          │ Filter: AWSLogs/*.json.gz
          ▼
┌─────────────────┐
│ Lambda Function │ (cloudtrail_processor)
│   Processor     │ • Downloads .json.gz file
│                 │ • Decompresses with gzip
│                 │ • Parses JSON records
│                 │ • Transforms for Splunk format
└─────────┬───────┘
          │ Sends individual events
          │ via firehose.put_record_batch()
          ▼
┌─────────────────┐
│ Kinesis Data    │ (Delivery stream to Splunk)
│   Firehose      │ • Buffers events (5MB or 60s)
│                 │ • Delivers via HTTPS to HEC
│                 │ • Retries failures
└─────────┬───────┘
          │ HTTPS POST with HEC token
          │ Authorization: Splunk <token>
          ▼
┌─────────────────┐
│     Splunk      │ (HTTP Event Collector)
│   HEC Endpoint  │ • Receives structured events
│                 │ • Indexes as sourcetype=aws:cloudtrail
└─────────────────┘

BACKUP PATH (for failures):
Firehose → S3 Backup Bucket (failed events for manual reprocessing)

MONITORING:
• Lambda CloudWatch Logs: /aws/lambda/cloudtrail-processor
• Firehose CloudWatch Logs: /aws/kinesisfirehose/delivery
• Metrics: DeliveryToSplunk.Success, Lambda errors, S3 object count
*/