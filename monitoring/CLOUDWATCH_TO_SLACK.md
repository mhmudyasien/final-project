# CloudWatch to Slack Integration

This guide shows how to send CloudWatch alarms to Slack using SNS and Lambda.

---

## Architecture

```
CloudWatch Alarm → SNS Topic → Lambda Function → Slack Webhook
```

---

## Setup Steps

### 1. Create SNS Topic

```bash
aws sns create-topic \
  --name cloudwatch-alerts \
  --region us-east-2

# Save the ARN
SNS_TOPIC_ARN=$(aws sns describe-topics --query 'Topics[?contains(TopicArn, `cloudwatch-alerts`)].TopicArn' --output text)
echo $SNS_TOPIC_ARN
```

### 2. Create Lambda Function

**lambda_function.py:**

```python
import json
import urllib3
import os

http = urllib3.PoolManager()

def lambda_handler(event, context):
    """
    Forward CloudWatch alarms to Slack
    """
    
    # Get Slack webhook from environment
    slack_webhook = os.environ['SLACK_WEBHOOK_URL']
    
    # Parse SNS message
    message = json.loads(event['Records'][0]['Sns']['Message'])
    
    alarm_name = message.get('AlarmName', 'Unknown')
    new_state = message.get('NewStateValue', 'UNKNOWN')
    reason = message.get('NewStateReason', 'No reason provided')
    region = message.get('Region', 'us-east-2')
    
    # Determine color based on state
    if new_state == 'ALARM':
        color = 'danger'
        emoji = ':rotating_light:'
    elif new_state == 'OK':
        color = 'good'
        emoji = ':white_check_mark:'
    else:
        color = 'warning'
        emoji = ':warning:'
    
    # Build Slack message
    slack_message = {
        'username': 'CloudWatch Alarms',
        'icon_emoji': ':aws:',
        'attachments': [
            {
                'color': color,
                'title': f'{emoji} CloudWatch Alarm: {alarm_name}',
                'fields': [
                    {
                        'title': 'State',
                        'value': new_state,
                        'short': True
                    },
                    {
                        'title': 'Region',
                        'value': region,
                        'short': True
                    },
                    {
                        'title': 'Reason',
                        'value': reason,
                        'short': False
                    }
                ],
                'footer': 'AWS CloudWatch',
                'ts': int(context.get_remaining_time_in_millis() / 1000)
            }
        ]
    }
    
    # Send to Slack
    encoded_msg = json.dumps(slack_message).encode('utf-8')
    resp = http.request('POST', slack_webhook, body=encoded_msg)
    
    return {
        'statusCode': resp.status,
        'body': json.dumps('Notification sent to Slack')
    }
```

### 3. Deploy Lambda Function

```bash
# Create deployment package
zip lambda_function.zip lambda_function.py

# Create IAM role for Lambda
aws iam create-role \
  --role-name cloudwatch-to-slack-lambda-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

# Attach basic execution policy
aws iam attach-role-policy \
  --role-name cloudwatch-to-slack-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Create Lambda function
aws lambda create-function \
  --function-name cloudwatch-to-slack \
  --runtime python3.11 \
  --role arn:aws:iam::ACCOUNT_ID:role/cloudwatch-to-slack-lambda-role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://lambda_function.zip \
  --environment Variables={SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL} \
  --region us-east-2
```

### 4. Subscribe Lambda to SNS

```bash
# Get Lambda ARN
LAMBDA_ARN=$(aws lambda get-function --function-name cloudwatch-to-slack --query 'Configuration.FunctionArn' --output text)

# Subscribe Lambda to SNS
aws sns subscribe \
  --topic-arn $SNS_TOPIC_ARN \
  --protocol lambda \
  --notification-endpoint $LAMBDA_ARN

# Grant SNS permission to invoke Lambda
aws lambda add-permission \
  --function-name cloudwatch-to-slack \
  --statement-id AllowSNSInvoke \
  --action lambda:InvokeFunction \
  --principal sns.amazonaws.com \
  --source-arn $SNS_TOPIC_ARN
```

### 5. Test Integration

```bash
# Trigger a test alarm
aws cloudwatch set-alarm-state \
  --alarm-name eks-high-cpu \
  --state-value ALARM \
  --state-reason "Testing Slack integration"

# Check Slack channel for notification
```

---

## Update CloudWatch Alarms

Update all alarms to use the SNS topic:

```bash
# Example: Update existing alarm
aws cloudwatch put-metric-alarm \
  --alarm-name eks-high-cpu \
  --alarm-description "EKS cluster CPU usage > 80%" \
  --metric-name node_cpu_utilization \
  --namespace ContainerInsights \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=ClusterName,Value=final-project-cluster \
  --alarm-actions $SNS_TOPIC_ARN \
  --ok-actions $SNS_TOPIC_ARN  # Also notify when alarm clears
```

---

## Advanced: Custom Slack Messages

Enhance Lambda to send richer messages:

```python
def format_eks_alarm(message):
    """Format EKS-specific alarms"""
    metric_name = message.get('Trigger', {}).get('MetricName', '')
    
    if 'cpu' in metric_name.lower():
        return {
            'title': ':fire: High CPU Usage Detected',
            'color': 'danger',
            'text': 'EKS cluster is experiencing high CPU usage',
            'actions': [
                {
                    'type': 'button',
                    'text': 'View Metrics',
                    'url': f"https://console.aws.amazon.com/cloudwatch/home?region={message['Region']}#alarmsV2:alarm/{message['AlarmName']}"
                },
                {
                    'type': 'button',
                    'text': 'Scale Cluster',
                    'url': 'https://console.aws.amazon.com/eks/home'
                }
            ]
        }
    
    return None

# In lambda_handler, use custom formatting if available
custom_format = format_eks_alarm(message)
if custom_format:
    slack_message['attachments'][0].update(custom_format)
```

---

## Monitoring Checklist

- [ ] SNS topic created
- [ ] Lambda function deployed
- [ ] Lambda subscribed to SNS
- [ ] Slack webhook configured in Lambda
- [ ] CloudWatch alarms updated with SNS topic
- [ ] Test notification sent
- [ ] Slack channel configured
- [ ] Team members added to channel

---

## Cost

- **SNS**: $0.50 per 1M requests
- **Lambda**: Free tier covers most use cases
- **Total**: ~$1-2/month for typical usage
