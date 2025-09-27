# cloudtrail_processor.py
# Lambda function that processes CloudTrail logs from S3 and sends them to Kinesis Data Firehose

import json
import boto3
import gzip
import os
from urllib.parse import unquote_plus
from datetime import datetime
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
firehose_client = boto3.client('firehose')

# Environment variables
FIREHOSE_STREAM_NAME = os.environ['FIREHOSE_STREAM_NAME']
SPLUNK_SOURCE = os.environ.get('SPLUNK_SOURCE', 'aws:cloudtrail')
SPLUNK_SOURCETYPE = os.environ.get('SPLUNK_SOURCETYPE', 'aws:cloudtrail')

"""
s3----->lamda function----->firehose----->splunk
lambda_handler ----> process_cloudtrail_file -----> transform_cloudtrail_record----> send_batch_to_firehose
"""


def lambda_handler(event, context):
    """
    Main Lambda handler function
    Processes S3 events containing CloudTrail logs and forwards to Firehose
    """
    
    logger.info(f"Processing {len(event['Records'])} S3 event records")
    
    total_events_processed = 0
    
    # Process each S3 event record
    for record in event['Records']:
        try:
            # Extract S3 object information from the event
            bucket_name = record['s3']['bucket']['name']
            object_key = unquote_plus(record['s3']['object']['key'])
            
            logger.info(f"Processing CloudTrail file: s3://{bucket_name}/{object_key}")
            
            # Download and process the CloudTrail log file
            events_processed = process_cloudtrail_file(bucket_name, object_key)
            total_events_processed += events_processed
            
            logger.info(f"Successfully processed {events_processed} events from {object_key}")
            
        except Exception as e:
            logger.error(f"Error processing S3 record {record}: {str(e)}")
            # Continue processing other records even if one fails
            continue
    
    logger.info(f"Total events processed and sent to Firehose: {total_events_processed}")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': f'Successfully processed {total_events_processed} CloudTrail events',
            'firehoseStream': FIREHOSE_STREAM_NAME
        })
    }

def process_cloudtrail_file(bucket_name, object_key):
    """
    Download, decompress, and process a CloudTrail log file from S3
    
    Args:
        bucket_name (str): S3 bucket name
        object_key (str): S3 object key
    
    Returns:
        int: Number of events processed
    """
    
    try:
        # Download the CloudTrail log file from S3
        logger.info(f"Downloading file from S3: {object_key}")
        response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        
        # CloudTrail files are gzip compressed - decompress them
        with gzip.GzipFile(fileobj=response['Body']) as gzipfile:
            content = gzipfile.read().decode('utf-8')
        
        # Parse the JSON content
        cloudtrail_data = json.loads(content)
        
        # Extract individual CloudTrail records
        records = cloudtrail_data.get('Records', [])
        logger.info(f"Found {len(records)} CloudTrail events in file")
        
        if not records:
            logger.warning(f"No CloudTrail records found in file {object_key}")
            return 0
        
        # Process records in batches (Firehose has a 500 record limit per batch)
        batch_size = 500
        total_sent = 0
        
        for i in range(0, len(records), batch_size):
            batch = records[i:i + batch_size]
            sent_count = send_batch_to_firehose(batch)
            total_sent += sent_count
            
            logger.info(f"Sent batch {i//batch_size + 1}: {sent_count} records")
        
        return total_sent
        
    except Exception as e:
        logger.error(f"Error processing CloudTrail file {object_key}: {str(e)}")
        raise e

def send_batch_to_firehose(cloudtrail_records):
    """
    Send a batch of CloudTrail records to Kinesis Data Firehose
    
    Args:
        cloudtrail_records (list): List of CloudTrail event records
    
    Returns:
        int: Number of records successfully sent
    """
    
    # Transform CloudTrail records to Splunk format
    firehose_records = []
    
    for record in cloudtrail_records:
        try:
            # Transform the CloudTrail record for Splunk
            splunk_event = transform_cloudtrail_record(record)
            
            # Convert to JSON string and add newline (required for Splunk HEC)
            event_data = json.dumps(splunk_event) + '\n'
            
            # Create Firehose record
            firehose_records.append({
                'Data': event_data.encode('utf-8')
            })
            
        except Exception as e:
            logger.error(f"Error transforming CloudTrail record: {str(e)}")
            # Skip this record and continue with others
            continue
    
    if not firehose_records:
        logger.warning("No valid records to send to Firehose")
        return 0
    
    try:
        # Send batch to Kinesis Data Firehose
        response = firehose_client.put_record_batch(
            DeliveryStreamName=FIREHOSE_STREAM_NAME,
            Records=firehose_records
        )
        
        # Check for failures
        failed_count = response.get('FailedPutCount', 0)
        successful_count = len(firehose_records) - failed_count
        
        if failed_count > 0:
            logger.warning(f"Failed to send {failed_count} out of {len(firehose_records)} records to Firehose")
            
            # Log details about failed records
            for idx, result in enumerate(response.get('RequestResponses', [])):
                if 'ErrorCode' in result:
                    logger.error(f"Record {idx} failed: {result['ErrorCode']} - {result.get('ErrorMessage', '')}")
        
        logger.info(f"Successfully sent {successful_count} records to Firehose stream: {FIREHOSE_STREAM_NAME}")
        return successful_count
        
    except Exception as e:
        logger.error(f"Error sending batch to Firehose: {str(e)}")
        raise e

def transform_cloudtrail_record(cloudtrail_record):
    """
    Transform a CloudTrail record into Splunk HEC format
    
    Args:
        cloudtrail_record (dict): Raw CloudTrail event record
    
    Returns:
        dict: Splunk HEC formatted event
    """
    
    # Extract timestamp and convert to epoch format for Splunk
    event_time_str = cloudtrail_record.get('eventTime', datetime.utcnow().isoformat())
    try:
        # Parse ISO format timestamp: 2024-01-15T10:30:45Z
        dt = datetime.fromisoformat(event_time_str.replace('Z', '+00:00'))
        epoch_time = int(dt.timestamp())
    except (ValueError, AttributeError):
        # Fallback to current time if parsing fails
        epoch_time = int(datetime.utcnow().timestamp())
    
    # Extract key information for Splunk indexing
    event_name = cloudtrail_record.get('eventName', 'Unknown')
    event_source = cloudtrail_record.get('eventSource', 'Unknown')
    aws_region = cloudtrail_record.get('awsRegion', 'Unknown')
    source_ip = cloudtrail_record.get('sourceIPAddress', 'Unknown')
    user_identity = cloudtrail_record.get('userIdentity', {})
    user_type = user_identity.get('type', 'Unknown')
    
    # Create Splunk HEC event format
    splunk_event = {
        'time': epoch_time,
        'host': aws_region,
        'source': SPLUNK_SOURCE,
        'sourcetype': SPLUNK_SOURCETYPE,
        'event': cloudtrail_record,  # Full CloudTrail record as the event
        'fields': {
            # Additional indexed fields for better searching
            'aws_account_id': cloudtrail_record.get('recipientAccountId', ''),
            'aws_region': aws_region,
            'event_name': event_name,
            'event_source': event_source,
            'event_type': cloudtrail_record.get('eventType', ''),
            'user_identity_type': user_type,
            'user_name': user_identity.get('userName', ''),
            'source_ip_address': source_ip,
            'user_agent': cloudtrail_record.get('userAgent', ''),
            'api_version': cloudtrail_record.get('apiVersion', ''),
            'management_event': cloudtrail_record.get('managementEvent', True),
            'read_only': cloudtrail_record.get('readOnly', False),
            'event_category': cloudtrail_record.get('eventCategory', 'Management'),
            'request_id': cloudtrail_record.get('requestID', ''),
            'service_name': event_source.split('.')[0] if '.' in event_source else event_source,
            'error_code': cloudtrail_record.get('errorCode', ''),
            'error_message': cloudtrail_record.get('errorMessage', '')
        }
    }
    
    # Add resource information if available
    resources = cloudtrail_record.get('resources', [])
    if resources:
        resource_arns = [res.get('resourceARN', '') for res in resources if res.get('resourceARN')]
        resource_types = [res.get('resourceType', '') for res in resources if res.get('resourceType')]
        
        splunk_event['fields']['resource_arns'] = resource_arns
        splunk_event['fields']['resource_types'] = list(set(resource_types))  # Remove duplicates
    
    # Add request parameters summary (for better searchability)
    request_params = cloudtrail_record.get('requestParameters', {})
    if request_params and isinstance(request_params, dict):
        # Extract commonly searched fields
        if 'instanceId' in request_params:
            splunk_event['fields']['instance_id'] = request_params['instanceId']
        if 'bucketName' in request_params:
            splunk_event['fields']['bucket_name'] = request_params['bucketName']
        if 'key' in request_params:
            splunk_event['fields']['object_key'] = request_params['key']
        if 'groupId' in request_params:
            splunk_event['fields']['security_group_id'] = request_params['groupId']
        if 'vpcId' in request_params:
            splunk_event['fields']['vpc_id'] = request_params['vpcId']
    
    # Add response elements summary
    response_elements = cloudtrail_record.get('responseElements', {})
    if response_elements and isinstance(response_elements, dict):
        if 'instanceId' in response_elements:
            splunk_event['fields']['created_instance_id'] = response_elements['instanceId']
    
    return splunk_event

def get_event_severity(cloudtrail_record):
    """
    Determine event severity based on CloudTrail record content
    
    Args:
        cloudtrail_record (dict): CloudTrail event record
    
    Returns:
        str: Event severity (low, medium, high, critical)
    """
    
    event_name = cloudtrail_record.get('eventName', '').lower()
    error_code = cloudtrail_record.get('errorCode', '')
    
    # Critical events
    critical_events = [
        'deletetrail', 'stoptrail', 'putbucketpolicy', 'deletebucket',
        'createuser', 'deleteuser', 'attachuserpolicy', 'detachuserpolicy',
        'createrole', 'deleterole', 'attachrolepolicy', 'detachrolepolicy'
    ]
    
    # High severity events
    high_events = [
        'createaccesskey', 'deleteaccesskey', 'updateaccesskey',
        'authorizeassumerolewithwebidentity', 'assumeassumerolewithsaml',
        'terminateinstance', 'createvpc', 'deletevpc'
    ]
    
    # Medium severity events
    medium_events = [
        'runinstance', 'stopinstance', 'startinstance',
        'createtags', 'deletetags', 'modifyinstance'
    ]
    
    if any(critical_event in event_name for critical_event in critical_events):
        return 'critical'
    elif any(high_event in event_name for high_event in high_events):
        return 'high'
    elif any(medium_event in event_name for medium_event in medium_events):
        return 'medium'
    elif error_code:
        return 'high'  # Any error is high severity
    else:
        return 'low'

# Example of how the transformed data looks in Splunk:
"""
Example Splunk Event after transformation:

{
  "time": 1642248645,
  "host": "us-east-1", 
  "source": "aws:cloudtrail",
  "sourcetype": "aws:cloudtrail",
  "event": {
    "eventVersion": "1.08",
    "userIdentity": {
      "type": "IAMUser",
      "principalId": "AIDACKCEVSQ6C2EXAMPLE",
      "arn": "arn:aws:iam::123456789012:user/johndoe",
      "accountId": "123456789012",
      "userName": "johndoe"
    },
    "eventTime": "2024-01-15T10:30:45Z",
    "eventSource": "ec2.amazonaws.com",
    "eventName": "RunInstances",
    "awsRegion": "us-east-1",
    "sourceIPAddress": "203.0.113.12",
    "userAgent": "aws-cli/2.0.55 Python/3.8.5",
    "requestParameters": {
      "instancesSet": {
        "items": [
          {
            "imageId": "ami-0abcdef1234567890",
            "minCount": 1,
            "maxCount": 1,
            "instanceType": "t3.micro"
          }
        ]
      }
    },
    "responseElements": {
      "instancesSet": {
        "items": [
          {
            "instanceId": "i-0abcdef1234567890",
            "imageId": "ami-0abcdef1234567890",
            "state": {
              "code": 0,
              "name": "pending"
            },
            "instanceType": "t3.micro"
          }
        ]
      }
    }
  },
  "fields": {
    "aws_account_id": "123456789012",
    "aws_region": "us-east-1", 
    "event_name": "RunInstances",
    "event_source": "ec2.amazonaws.com",
    "user_identity_type": "IAMUser",
    "user_name": "johndoe",
    "source_ip_address": "203.0.113.12",
    "service_name": "ec2",
    "created_instance_id": "i-0abcdef1234567890"
  }
}

This allows Splunk searches like:
- index=main sourcetype="aws:cloudtrail" event_name="RunInstances"
- index=main sourcetype="aws:cloudtrail" user_name="johndoe"
- index=main sourcetype="aws:cloudtrail" source_ip_address="203.0.113.12"
- index=main sourcetype="aws:cloudtrail" service_name="ec2"
"""