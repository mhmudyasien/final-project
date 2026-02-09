# Monitoring and Notifications

Complete monitoring and alerting setup for the Final Project infrastructure and applications.

---

## Overview

This directory contains configuration and guides for:

1. **CloudWatch Monitoring** - EKS cluster, applications, and infrastructure metrics
2. **Slack Notifications** - Azure DevOps pipeline alerts
3. **CloudWatch-to-Slack Integration** - Infrastructure alerts to Slack

---

## Quick Start

### 1. CloudWatch Setup

**Install Container Insights:**
```bash
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml
```

**Verify:**
```bash
kubectl get pods -n amazon-cloudwatch
```

**View logs:**
```bash
aws logs tail /aws/containerinsights/final-project-cluster/application --follow
```

### 2. Slack Notifications for Azure DevOps

**Create Slack webhook:**
1. Go to https://api.slack.com/apps
2. Create app → Enable Incoming Webhooks
3. Add webhook to channel
4. Copy webhook URL

**Add to Azure DevOps:**
1. Pipelines → Library → `common-variables`
2. Add variable: `slack-webhook-url` (mark as secret)
3. Use in pipelines:
   ```yaml
   - template: ../pipelines/templates/notifications/slack-notify.yml
     parameters:
       webhookUrl: $(slack-webhook-url)
       message: 'Build completed'
       status: 'success'
   ```

### 3. CloudWatch to Slack

**Deploy Lambda function:**
```bash
# Create SNS topic
aws sns create-topic --name cloudwatch-alerts --region us-east-2

# Deploy Lambda (see CLOUDWATCH_TO_SLACK.md)
aws lambda create-function \
  --function-name cloudwatch-to-slack \
  --runtime python3.11 \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://lambda_function.zip \
  --environment Variables={SLACK_WEBHOOK_URL=YOUR_WEBHOOK}
```

---

## Documentation

| File | Description |
|------|-------------|
| [CLOUDWATCH_SETUP.md](CLOUDWATCH_SETUP.md) | Complete CloudWatch monitoring setup with Container Insights, logging, metrics, alarms, and dashboards |
| [SLACK_NOTIFICATIONS.md](SLACK_NOTIFICATIONS.md) | Azure DevOps pipeline Slack integration with custom templates and examples |
| [CLOUDWATCH_TO_SLACK.md](CLOUDWATCH_TO_SLACK.md) | Lambda function to forward CloudWatch alarms to Slack |

---

## Monitoring Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     EKS Cluster                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Backend    │  │   Frontend   │  │  CloudWatch  │     │
│  │     Pods     │  │     Pods     │  │    Agent     │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                  │                  │             │
│         └──────────────────┴──────────────────┘             │
│                            │                                │
└────────────────────────────┼────────────────────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │   CloudWatch    │
                    │  Logs & Metrics │
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
                    ▼                 ▼
            ┌──────────────┐  ┌──────────────┐
            │  Dashboards  │  │    Alarms    │
            └──────────────┘  └──────┬───────┘
                                     │
                                     ▼
                              ┌─────────────┐
                              │  SNS Topic  │
                              └──────┬──────┘
                                     │
                                     ▼
                              ┌─────────────┐
                              │   Lambda    │
                              └──────┬──────┘
                                     │
                                     ▼
                              ┌─────────────┐
                              │    Slack    │
                              └─────────────┘

┌─────────────────────────────────────────────────────────────┐
│                  Azure DevOps Pipelines                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Backend    │  │   Frontend   │  │Infrastructure│     │
│  │   Pipeline   │  │   Pipeline   │  │   Pipeline   │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                  │                  │             │
│         └──────────────────┴──────────────────┘             │
│                            │                                │
└────────────────────────────┼────────────────────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ Slack Webhook   │
                    └────────┬────────┘
                             │
                             ▼
                      ┌─────────────┐
                      │    Slack    │
                      └─────────────┘
```

---

## Metrics Collected

### EKS Cluster Metrics

- **CPU**: `node_cpu_utilization`, `pod_cpu_utilization`
- **Memory**: `node_memory_utilization`, `pod_memory_utilization`
- **Network**: `node_network_total_bytes`, `pod_network_rx_bytes`
- **Disk**: `node_filesystem_utilization`
- **Pods**: `pod_number_of_container_restarts`, `cluster_failed_node_count`

### Application Metrics

- **API**: Request count, response time, error rate
- **Database**: Query time, connection pool usage
- **Cache**: Hit rate, miss rate

### Infrastructure Metrics

- **ALB**: Target response time, healthy/unhealthy hosts, 5xx errors
- **RDS**: CPU, memory, storage, connections
- **ElastiCache**: CPU, memory, cache hits/misses

---

## Alarms Configuration

### Critical Alarms (Immediate Action)

| Alarm | Threshold | Action |
|-------|-----------|--------|
| EKS High CPU | > 80% for 10 min | Scale nodes |
| EKS High Memory | > 85% for 10 min | Scale nodes |
| Pod Failures | > 5 restarts in 5 min | Check logs |
| ALB Unhealthy Targets | > 0 for 2 min | Check pods |
| RDS High CPU | > 80% for 10 min | Optimize queries |
| High Error Rate | > 5% for 5 min | Check logs |

### Warning Alarms (Monitor)

| Alarm | Threshold | Action |
|-------|-----------|--------|
| High Response Time | > 1s avg for 5 min | Investigate |
| Low Cache Hit Rate | < 70% for 10 min | Review cache strategy |
| RDS Low Storage | < 10GB | Plan upgrade |

---

## Slack Channels

Recommended channel structure:

| Channel | Purpose | Notifications |
|---------|---------|---------------|
| `#devops-alerts` | General infrastructure alerts | CloudWatch alarms, critical issues |
| `#backend-builds` | Backend CI/CD | Build status, test results |
| `#frontend-builds` | Frontend CI/CD | Build status, test results |
| `#production-deploys` | Production changes | Deployment approvals, completions |
| `#security-alerts` | Security issues | Vulnerability scans, policy violations |

---

## Notification Examples

### Build Success
```
✅ Backend build completed
Pipeline: Backend CI/CD
Build: #123
Branch: main
Duration: 5m 23s
[View Build] [View Commit]
```

### Build Failure
```
❌ Backend build failed
Pipeline: Backend CI/CD
Build: #124
Branch: feature/new-api
Error: Unit tests failed (3 failures)
[View Build] [View Logs]
```

### CloudWatch Alarm
```
🚨 CloudWatch Alarm: eks-high-cpu
State: ALARM
Region: us-east-2
Reason: Threshold Crossed: 1 datapoint [85.2] was greater than threshold [80.0]
[View Metrics] [View Dashboard]
```

### Deployment Approval
```
⚠️ Production deployment approval required
Application: Backend API
Version: v1.2.3
Requested By: John Doe
Branch: main
[Review & Approve]
```

---

## Cost Estimates

### CloudWatch

| Service | Usage | Cost/Month |
|---------|-------|------------|
| Logs ingestion | ~50GB | $25 |
| Logs storage (30 days) | ~1.5TB | $45 |
| Custom metrics | ~50 metrics | $15 |
| Alarms | ~20 alarms | $2 |
| Dashboards | 2 dashboards | $6 |
| **Total** | | **~$93** |

### Slack + Lambda

| Service | Usage | Cost/Month |
|---------|-------|------------|
| Slack | Free tier | $0 |
| SNS | ~10K notifications | $0.50 |
| Lambda | ~10K invocations | $0 (free tier) |
| **Total** | | **~$0.50** |

**Total Monitoring Cost: ~$94/month**

---

## Optimization Tips

1. **Reduce log retention** in dev (7 days vs 30 days)
2. **Filter logs** before sending to CloudWatch
3. **Use metric filters** instead of custom metrics where possible
4. **Aggregate metrics** before sending
5. **Limit Slack notifications** to critical events only

---

## Troubleshooting

### CloudWatch Logs Not Appearing

```bash
# Check Fluent Bit pods
kubectl get pods -n amazon-cloudwatch

# Check logs
kubectl logs -n amazon-cloudwatch -l k8s-app=fluent-bit

# Verify IAM permissions
aws iam get-role-policy --role-name final-project-eks-node-role --policy-name CloudWatchAgentServerPolicy
```

### Slack Notifications Not Working

```bash
# Test webhook manually
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test message"}' \
  YOUR_WEBHOOK_URL

# Check Azure DevOps variable
# Ensure slack-webhook-url is set and marked as secret
```

### Lambda Not Triggering

```bash
# Check Lambda logs
aws logs tail /aws/lambda/cloudwatch-to-slack --follow

# Verify SNS subscription
aws sns list-subscriptions-by-topic --topic-arn YOUR_SNS_TOPIC_ARN

# Test manually
aws sns publish \
  --topic-arn YOUR_SNS_TOPIC_ARN \
  --message "Test message"
```

---

## Next Steps

1. ✅ Install CloudWatch Container Insights
2. ✅ Configure application logging (JSON format)
3. ✅ Create CloudWatch alarms
4. ✅ Set up SNS topic
5. ✅ Deploy Lambda function
6. ✅ Create Slack webhooks
7. ✅ Add Slack notifications to pipelines
8. ✅ Create CloudWatch dashboards
9. ✅ Test all integrations
10. ✅ Document runbooks for common alerts

---

## Additional Resources

- [CloudWatch Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html)
- [Slack API Documentation](https://api.slack.com/)
- [Azure DevOps Notifications](https://docs.microsoft.com/en-us/azure/devops/notifications/)
