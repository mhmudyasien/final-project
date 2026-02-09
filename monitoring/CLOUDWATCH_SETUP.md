# CloudWatch Monitoring Setup for EKS

This guide covers setting up comprehensive CloudWatch monitoring for your EKS cluster, applications, and infrastructure.

---

## Table of Contents

1. [Container Insights Setup](#container-insights-setup)
2. [Application Logging](#application-logging)
3. [Custom Metrics](#custom-metrics)
4. [CloudWatch Alarms](#cloudwatch-alarms)
5. [Dashboards](#dashboards)

---

## Container Insights Setup

### 1. Enable Container Insights for EKS

```bash
# Install CloudWatch agent and Fluent Bit
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml

# Verify installation
kubectl get pods -n amazon-cloudwatch
```

### 2. IAM Policy for CloudWatch

Create IAM policy for EKS nodes:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
        "ec2:DescribeVolumes",
        "ec2:DescribeTags",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
        "logs:DescribeLogGroups",
        "logs:CreateLogStream",
        "logs:CreateLogGroup"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
    }
  ]
}
```

Attach to node group role:

```bash
aws iam attach-role-policy \
  --role-name final-project-eks-node-role \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
```

### 3. Configure CloudWatch Agent

Create ConfigMap for custom metrics:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cwagentconfig
  namespace: amazon-cloudwatch
data:
  cwagentconfig.json: |
    {
      "logs": {
        "metrics_collected": {
          "kubernetes": {
            "cluster_name": "final-project-cluster",
            "metrics_collection_interval": 60
          }
        },
        "force_flush_interval": 5
      },
      "metrics": {
        "namespace": "ContainerInsights",
        "metrics_collected": {
          "cpu": {
            "measurement": [
              {"name": "cpu_usage_idle", "rename": "CPU_USAGE_IDLE", "unit": "Percent"},
              {"name": "cpu_usage_iowait", "rename": "CPU_USAGE_IOWAIT", "unit": "Percent"},
              "cpu_time_guest"
            ],
            "metrics_collection_interval": 60,
            "totalcpu": false
          },
          "disk": {
            "measurement": [
              {"name": "used_percent", "rename": "DISK_USED_PERCENT", "unit": "Percent"},
              "inodes_free"
            ],
            "metrics_collection_interval": 60,
            "resources": ["*"]
          },
          "mem": {
            "measurement": [
              {"name": "mem_used_percent", "rename": "MEM_USED_PERCENT", "unit": "Percent"}
            ],
            "metrics_collection_interval": 60
          },
          "net": {
            "measurement": [
              "bytes_sent",
              "bytes_recv",
              "drop_in",
              "drop_out"
            ],
            "metrics_collection_interval": 60
          }
        }
      }
    }
```

Apply:
```bash
kubectl apply -f cloudwatch-agent-config.yaml
```

---

## Application Logging

### 1. Fluent Bit Configuration

Fluent Bit automatically collects logs from all pods. Logs are sent to CloudWatch Logs.

**Log Groups Created:**
- `/aws/containerinsights/final-project-cluster/application`
- `/aws/containerinsights/final-project-cluster/host`
- `/aws/containerinsights/final-project-cluster/dataplane`

### 2. Application Log Format

Update your applications to output structured JSON logs:

**Backend (Python/FastAPI):**

```python
import logging
import json
from datetime import datetime

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_data = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "environment": os.getenv("ENVIRONMENT", "dev"),
            "service": "backend",
        }
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_data)

# Configure logging
handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logging.root.addHandler(handler)
logging.root.setLevel(logging.INFO)
```

**Frontend (Nginx access logs):**

Already in JSON format via Nginx configuration.

### 3. Query Logs with CloudWatch Insights

```sql
-- Find errors in last hour
fields @timestamp, @message
| filter @logStream like /backend/
| filter level = "ERROR"
| sort @timestamp desc
| limit 100

-- API response times
fields @timestamp, message.duration
| filter @logStream like /backend/
| filter message.path like /api/
| stats avg(message.duration), max(message.duration), min(message.duration) by bin(5m)

-- 5xx errors by endpoint
fields @timestamp, message.path, message.status
| filter message.status >= 500
| stats count() by message.path
| sort count desc
```

---

## Custom Metrics

### 1. Application Metrics with CloudWatch SDK

**Backend (Python):**

```python
import boto3
from datetime import datetime

cloudwatch = boto3.client('cloudwatch', region_name='us-east-2')

def put_metric(metric_name, value, unit='Count', dimensions=None):
    """Send custom metric to CloudWatch"""
    if dimensions is None:
        dimensions = []
    
    cloudwatch.put_metric_data(
        Namespace='FinalProject/Application',
        MetricData=[
            {
                'MetricName': metric_name,
                'Value': value,
                'Unit': unit,
                'Timestamp': datetime.utcnow(),
                'Dimensions': dimensions + [
                    {'Name': 'Environment', 'Value': os.getenv('ENVIRONMENT', 'dev')},
                    {'Name': 'Service', 'Value': 'backend'}
                ]
            }
        ]
    )

# Usage examples
put_metric('APIRequests', 1, 'Count')
put_metric('DatabaseQueryTime', 0.045, 'Seconds')
put_metric('CacheHitRate', 85.5, 'Percent')
```

### 2. Prometheus Metrics (Alternative)

If you prefer Prometheus-style metrics, use CloudWatch Container Insights with Prometheus support:

```bash
# Install Prometheus
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/service/cwagent-prometheus/prometheus-eks.yaml
```

---

## CloudWatch Alarms

### 1. EKS Cluster Alarms

```bash
# High CPU usage
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
  --alarm-actions arn:aws:sns:us-east-2:ACCOUNT_ID:alerts

# High memory usage
aws cloudwatch put-metric-alarm \
  --alarm-name eks-high-memory \
  --alarm-description "EKS cluster memory usage > 85%" \
  --metric-name node_memory_utilization \
  --namespace ContainerInsights \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 85 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=ClusterName,Value=final-project-cluster \
  --alarm-actions arn:aws:sns:us-east-2:ACCOUNT_ID:alerts

# Pod failures
aws cloudwatch put-metric-alarm \
  --alarm-name eks-pod-failures \
  --alarm-description "Pod failures detected" \
  --metric-name pod_number_of_container_restarts \
  --namespace ContainerInsights \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=ClusterName,Value=final-project-cluster \
  --alarm-actions arn:aws:sns:us-east-2:ACCOUNT_ID:alerts
```

### 2. Application Alarms

```bash
# High error rate
aws cloudwatch put-metric-alarm \
  --alarm-name app-high-error-rate \
  --alarm-description "Application error rate > 5%" \
  --metric-name ErrorRate \
  --namespace FinalProject/Application \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=Environment,Value=prod Name=Service,Value=backend \
  --alarm-actions arn:aws:sns:us-east-2:ACCOUNT_ID:alerts

# Slow API responses
aws cloudwatch put-metric-alarm \
  --alarm-name app-slow-response \
  --alarm-description "API response time > 1 second" \
  --metric-name ResponseTime \
  --namespace FinalProject/Application \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 1000 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=Environment,Value=prod \
  --alarm-actions arn:aws:sns:us-east-2:ACCOUNT_ID:alerts
```

### 3. ALB Alarms

```bash
# Unhealthy targets
aws cloudwatch put-metric-alarm \
  --alarm-name alb-unhealthy-targets \
  --alarm-description "ALB has unhealthy targets" \
  --metric-name UnHealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=LoadBalancer,Value=app/k8s-prod-applicat-xxx/yyy \
  --alarm-actions arn:aws:sns:us-east-2:ACCOUNT_ID:alerts

# High 5xx errors
aws cloudwatch put-metric-alarm \
  --alarm-name alb-high-5xx \
  --alarm-description "ALB 5xx error rate > 5%" \
  --metric-name HTTPCode_Target_5XX_Count \
  --namespace AWS/ApplicationELB \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 50 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=LoadBalancer,Value=app/k8s-prod-applicat-xxx/yyy \
  --alarm-actions arn:aws:sns:us-east-2:ACCOUNT_ID:alerts
```

### 4. RDS Alarms

```bash
# High CPU
aws cloudwatch put-metric-alarm \
  --alarm-name rds-high-cpu \
  --alarm-description "RDS CPU > 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=DBInstanceIdentifier,Value=final-project-db \
  --alarm-actions arn:aws:sns:us-east-2:ACCOUNT_ID:alerts

# Low free storage
aws cloudwatch put-metric-alarm \
  --alarm-name rds-low-storage \
  --alarm-description "RDS free storage < 10GB" \
  --metric-name FreeStorageSpace \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 10000000000 \
  --comparison-operator LessThanThreshold \
  --dimensions Name=DBInstanceIdentifier,Value=final-project-db \
  --alarm-actions arn:aws:sns:us-east-2:ACCOUNT_ID:alerts
```

---

## Dashboards

### 1. Create Main Dashboard

```bash
aws cloudwatch put-dashboard \
  --dashboard-name final-project-overview \
  --dashboard-body file://dashboard-config.json
```

**dashboard-config.json:**

```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["ContainerInsights", "node_cpu_utilization", {"stat": "Average"}],
          [".", "node_memory_utilization", {"stat": "Average"}]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-2",
        "title": "EKS Cluster Resources",
        "yAxis": {"left": {"min": 0, "max": 100}}
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "TargetResponseTime", {"stat": "Average"}],
          [".", "RequestCount", {"stat": "Sum", "yAxis": "right"}]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-2",
        "title": "ALB Performance"
      }
    },
    {
      "type": "log",
      "properties": {
        "query": "SOURCE '/aws/containerinsights/final-project-cluster/application'\n| filter @logStream like /backend/\n| filter level = 'ERROR'\n| stats count() by bin(5m)",
        "region": "us-east-2",
        "title": "Error Rate",
        "stacked": false
      }
    }
  ]
}
```

### 2. Access Dashboard

```bash
# Get dashboard URL
echo "https://console.aws.amazon.com/cloudwatch/home?region=us-east-2#dashboards:name=final-project-overview"
```

---

## Cost Optimization

### CloudWatch Costs

- **Logs ingestion**: $0.50/GB
- **Logs storage**: $0.03/GB/month
- **Metrics**: $0.30/metric/month
- **Alarms**: $0.10/alarm/month
- **Dashboards**: $3/dashboard/month

### Optimization Tips

1. **Set log retention**:
   ```bash
   aws logs put-retention-policy \
     --log-group-name /aws/containerinsights/final-project-cluster/application \
     --retention-in-days 7  # dev
   
   aws logs put-retention-policy \
     --log-group-name /aws/containerinsights/final-project-cluster/application \
     --retention-in-days 30  # prod
   ```

2. **Filter logs before sending**:
   - Only send ERROR and WARN logs from dev
   - Filter out health check logs

3. **Use metric filters** instead of custom metrics where possible

4. **Aggregate metrics** before sending to CloudWatch

---

## Monitoring Checklist

- [ ] Container Insights installed
- [ ] IAM policies attached to node role
- [ ] CloudWatch agent configured
- [ ] Application logging in JSON format
- [ ] Custom metrics implemented
- [ ] Alarms created for critical metrics
- [ ] SNS topic for alerts configured
- [ ] Dashboard created
- [ ] Log retention policies set
- [ ] Cost alerts configured

---

## Useful Commands

```bash
# View logs
aws logs tail /aws/containerinsights/final-project-cluster/application --follow

# Query logs
aws logs start-query \
  --log-group-name /aws/containerinsights/final-project-cluster/application \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields @timestamp, @message | filter level = "ERROR" | sort @timestamp desc'

# List metrics
aws cloudwatch list-metrics --namespace ContainerInsights

# Get metric statistics
aws cloudwatch get-metric-statistics \
  --namespace ContainerInsights \
  --metric-name node_cpu_utilization \
  --dimensions Name=ClusterName,Value=final-project-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

---

## Next Steps

1. Set up SNS topic for alerts (see next section on Slack integration)
2. Configure Slack notifications
3. Create runbooks for common alerts
4. Set up automated remediation with Lambda
