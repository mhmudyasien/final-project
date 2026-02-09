# AWS Load Balancer Controller Setup Guide

## Overview

The Kubernetes Ingress resources use the **AWS Load Balancer Controller** to automatically provision Application Load Balancers (ALBs) in AWS.

---

## Prerequisites

### 1. Install AWS Load Balancer Controller

The AWS Load Balancer Controller must be installed in your EKS cluster.

#### Option A: Using Helm (Recommended)

```bash
# Add the EKS chart repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=final-project-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

#### Option B: Using kubectl

```bash
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

kubectl apply -f https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.6.0/v2_6_0_full.yaml
```

### 2. Create IAM Policy for Load Balancer Controller

```bash
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json
```

### 3. Create IAM Role and Service Account

```bash
eksctl create iamserviceaccount \
  --cluster=final-project-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve
```

---

## Ingress Configuration

### Environment-Specific Features

| Feature | Dev | Staging | Prod |
|---------|-----|---------|------|
| **Protocol** | HTTP only | HTTP + HTTPS | HTTPS only |
| **SSL Certificate** | ❌ No | ✅ Yes | ✅ Yes |
| **WAF** | ❌ No | ✅ Yes | ✅ Yes |
| **Access Logs** | ❌ No | ❌ No | ✅ S3 |
| **SSL Redirect** | ❌ No | ✅ Yes | N/A (HTTPS only) |

### Route Configuration

All environments route traffic as follows:

| Path | Service | Port | Description |
|------|---------|------|-------------|
| `/` | frontend | 80 | React application |
| `/api` | backend | 5000 | API endpoints |
| `/docs` | backend | 5000 | API documentation (Swagger/OpenAPI) |
| `/health` | backend | 5000 | Health check endpoint |

---

## Required Environment Variables

Before deploying, set these environment variables or update the Ingress manifests:

### All Environments

```bash
export ALB_SECURITY_GROUP_ID="sg-xxxxxxxxx"  # Security group for ALB
```

### Staging & Production

```bash
export ACM_CERTIFICATE_ARN="arn:aws:acm:us-east-2:ACCOUNT_ID:certificate/CERT_ID"
export WAF_ACL_ARN="arn:aws:wafv2:us-east-2:ACCOUNT_ID:regional/webacl/NAME/ID"
```

### Production Only

```bash
export S3_LOGS_BUCKET="my-alb-logs-bucket"
```

---

## Deployment

### 1. Create ACM Certificate (Staging & Prod)

```bash
# Request certificate
aws acm request-certificate \
  --domain-name "*.yourdomain.com" \
  --validation-method DNS \
  --region us-east-2

# Validate via DNS (follow AWS Console instructions)
```

### 2. Create WAF Web ACL (Staging & Prod)

```bash
# Create WAF Web ACL
aws wafv2 create-web-acl \
  --name production-web-acl \
  --scope REGIONAL \
  --region us-east-2 \
  --default-action Allow={} \
  --rules file://waf-rules.json
```

### 3. Create S3 Bucket for Logs (Prod)

```bash
# Create bucket
aws s3 mb s3://my-alb-logs-bucket --region us-east-2

# Enable bucket policy for ALB
aws s3api put-bucket-policy \
  --bucket my-alb-logs-bucket \
  --policy file://alb-logs-policy.json
```

### 4. Deploy Ingress

```bash
# Substitute environment variables
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ALB_SECURITY_GROUP_ID="sg-xxxxxxxxx"
export ACM_CERTIFICATE_ARN="arn:aws:acm:..."
export WAF_ACL_ARN="arn:aws:wafv2:..."
export S3_LOGS_BUCKET="my-alb-logs-bucket"

# Deploy dev
envsubst < k8s/dev/ingress.yaml | kubectl apply -f -

# Deploy staging
envsubst < k8s/staging/ingress.yaml | kubectl apply -f -

# Deploy prod
envsubst < k8s/prod/ingress.yaml | kubectl apply -f -
```

---

## Verification

### 1. Check Ingress Status

```bash
# Check Ingress resource
kubectl get ingress -n dev
kubectl get ingress -n staging
kubectl get ingress -n prod

# Get ALB DNS name
kubectl get ingress application-ingress -n prod -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### 2. Check ALB in AWS Console

1. Go to EC2 → Load Balancers
2. Find ALB created by controller (tagged with `kubernetes.io/ingress-name`)
3. Verify:
   - Listeners (HTTP/HTTPS)
   - Target groups
   - Health checks
   - Security groups

### 3. Test Access

```bash
# Get ALB URL
ALB_URL=$(kubectl get ingress application-ingress -n prod -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test frontend
curl http://$ALB_URL/

# Test backend API
curl http://$ALB_URL/api/health

# Test API docs
curl http://$ALB_URL/docs
```

---

## Troubleshooting

### Ingress Not Creating ALB

**Check controller logs:**
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

**Common issues:**
- IAM permissions missing
- Security group doesn't exist
- Subnet tags missing

### Required Subnet Tags

Ensure your subnets have these tags:

**Public subnets (for ALB):**
```
kubernetes.io/role/elb = 1
kubernetes.io/cluster/final-project-cluster = shared
```

**Private subnets (for pods):**
```
kubernetes.io/role/internal-elb = 1
kubernetes.io/cluster/final-project-cluster = shared
```

### Health Checks Failing

**Check backend health endpoint:**
```bash
kubectl port-forward -n prod deployment/backend 5000:5000
curl http://localhost:5000/health
```

**Adjust health check settings in Ingress:**
```yaml
alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
alb.ingress.kubernetes.io/healthy-threshold-count: '3'
```

### SSL Certificate Issues

**Verify certificate:**
```bash
aws acm describe-certificate \
  --certificate-arn $ACM_CERTIFICATE_ARN \
  --region us-east-2
```

**Certificate must be:**
- In the same region as ALB (us-east-2)
- Status: ISSUED
- Validation: Complete

---

## Security Best Practices

### 1. Security Groups

Create dedicated security group for ALB:

```bash
aws ec2 create-security-group \
  --group-name alb-security-group \
  --description "Security group for ALB" \
  --vpc-id vpc-xxxxxxxxx

# Allow HTTP/HTTPS from internet
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxxx \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxxx \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

### 2. WAF Rules

Recommended WAF rules:
- AWS Managed Rules (Core Rule Set)
- Rate limiting (1000 requests per 5 minutes)
- Geo-blocking (if applicable)
- SQL injection protection
- XSS protection

### 3. Access Logs

Enable access logs for compliance and debugging:

```yaml
alb.ingress.kubernetes.io/load-balancer-attributes: |
  access_logs.s3.enabled=true,
  access_logs.s3.bucket=my-alb-logs-bucket,
  access_logs.s3.prefix=prod-alb
```

---

## Cost Optimization

### ALB Pricing

- **Per ALB**: ~$16/month
- **Per LCU-hour**: ~$0.008/hour
- **Data processed**: Included in LCU

### Recommendations

1. **Share ALB across namespaces** (if security allows)
2. **Use path-based routing** instead of multiple ALBs
3. **Enable access logs only in prod** (storage costs)
4. **Monitor LCU usage** in CloudWatch

---

## Monitoring

### CloudWatch Metrics

Key metrics to monitor:
- `TargetResponseTime`
- `HTTPCode_Target_2XX_Count`
- `HTTPCode_Target_5XX_Count`
- `HealthyHostCount`
- `UnHealthyHostCount`
- `ActiveConnectionCount`

### Alarms

```bash
# Create alarm for unhealthy targets
aws cloudwatch put-metric-alarm \
  --alarm-name alb-unhealthy-targets \
  --alarm-description "Alert when targets are unhealthy" \
  --metric-name UnHealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold
```

---

## Additional Resources

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Ingress Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/guide/ingress/annotations/)
- [ALB Best Practices](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/best-practices.html)
