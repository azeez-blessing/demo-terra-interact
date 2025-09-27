import json
import urllib3
import os

def handler(event, context):
    """
    Lambda function to send CloudWatch alerts to Slack
    """
    webhook_url = os.environ['SLACK_WEBHOOK_URL']
    
    if not webhook_url:
        print("No Slack webhook URL configured")
        return
    
    # Parse SNS message
    message = json.loads(event['Records'][0]['Sns']['Message'])
    
    # Extract relevant information
    alarm_name = message.get('AlarmName', 'Unknown Alarm')
    alarm_description = message.get('AlarmDescription', 'No description available')
    new_state = message.get('NewStateValue', 'UNKNOWN')
    reason = message.get('NewStateReason', 'No reason provided')
    timestamp = message.get('StateChangeTime', 'Unknown time')
    
    # Determine color based on alarm state
    color_map = {
        'ALARM': '#FF0000',     # Red
        'OK': '#00FF00',        # Green
        'INSUFFICIENT_DATA': '#FFFF00'  # Yellow
    }
    color = color_map.get(new_state, '#808080')  # Gray for unknown
    
    # Create Slack message
    slack_message = {
        "attachments": [
            {
                "color": color,
                "title": f"CloudWatch Alarm: {alarm_name}",
                "fields": [
                    {
                        "title": "Status",
                        "value": new_state,
                        "short": True
                    },
                    {
                        "title": "Time",
                        "value": timestamp,
                        "short": True
                    },
                    {
                        "title": "Description",
                        "value": alarm_description,
                        "short": False
                    },
                    {
                        "title": "Reason",
                        "value": reason,
                        "short": False
                    }
                ],
                "footer": "AWS CloudWatch",
                "footer_icon": "https://aws.amazon.com/favicon.ico"
            }
        ]
    }
    
    # Send message to Slack
    http = urllib3.PoolManager()
    try:
        response = http.request(
            'POST',
            webhook_url,
            body=json.dumps(slack_message).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )
        
        if response.status == 200:
            print(f"Successfully sent alarm notification to Slack: {alarm_name}")
        else:
            print(f"Failed to send notification to Slack. Status: {response.status}")
            
    except Exception as e:
        print(f"Error sending notification to Slack: {str(e)}")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Notification processed')
    }