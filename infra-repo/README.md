# Infrastructure Repository - Terraform Pipeline

This repository contains Terraform infrastructure code with a comprehensive CI/CD pipeline.

## Pipeline Overview

The pipeline consists of 4 stages:

1. **Validate**: Terraform format check, validation, and linting
2. **Security Scan**: Checkov and tfsec security scanning
3. **Plan**: Generate and publish Terraform plan
4. **Apply**: Apply infrastructure changes (main branch only, manual approval)

## Triggers

- **CI Trigger**: Runs on push to `main` or `develop`
- **PR Trigger**: Runs on PRs to `main`
- **Path Filter**: Only triggers when Terraform code changes

## Stages

### 1. Validate

**Format Check:**
- `terraform fmt -check -recursive`
- Ensures consistent formatting
- Fails if formatting issues found

**Validation:**
- `terraform init -backend=false`
- `terraform validate`
- Checks syntax and configuration

**Linting:**
- tflint with AWS plugin
- Best practices enforcement
- Deprecated syntax detection

### 2. Security Scan

**Checkov:**
- Infrastructure security scanning
- Policy compliance checks
- CIS benchmark validation
- JUnit report generation

**tfsec:**
- AWS-specific security checks
- Misconfiguration detection
- Sensitive data exposure checks
- JUnit report generation

**Reports:**
- Published as test results
- Soft-fail mode (warnings only)
- Detailed findings in artifacts

### 3. Plan

**Terraform Plan:**
- Generates execution plan
- Detailed change preview
- Published as artifact
- Exit codes:
  - 0: No changes
  - 1: Error
  - 2: Changes detected

**Plan Review:**
- Manual review before apply
- Cost estimation (optional)
- Change impact analysis

### 4. Apply

**Requirements:**
- Only on `main` branch
- Manual approval required
- Plan artifact from previous stage

**Execution:**
- Applies planned changes
- Captures outputs
- Publishes outputs as artifact

**State Management:**
- Remote state in S3
- State locking with DynamoDB
- Encrypted at rest

## Environment Variables

Set in Azure DevOps Library:
- `awsRegion`: AWS region (default: us-east-2)
- `tfStateKey`: Terraform state key

## Service Connections

Required:
- `AWS-ServiceConnection`: AWS credentials for Terraform

## Backend Configuration

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

## Local Development

```bash
# Format code
terraform fmt -recursive

# Initialize
terraform init

# Validate
terraform validate

# Plan
terraform plan

# Apply
terraform apply

# Security scan
checkov -d .
tfsec .
```

## Infrastructure Components

- VPC with public/private/database subnets
- EKS cluster with managed node groups
- RDS PostgreSQL (isolated subnets)
- ElastiCache Redis (isolated subnets)
- Vault EC2 instance
- Security groups and network ACLs
- IAM roles and policies

## Security Best Practices

✅ **Encryption**: All data encrypted at rest and in transit
✅ **Least Privilege**: IAM roles with minimal permissions
✅ **Network Isolation**: Database in isolated subnets
✅ **Security Groups**: Restrictive ingress/egress rules
✅ **Auto-unsealing**: Vault with KMS
✅ **State Encryption**: Terraform state encrypted in S3

## Pipeline Artifacts

- Terraform plan file
- Terraform outputs (JSON)
- Checkov security report
- tfsec security report
- Validation results

## Deployment Workflow

1. **Develop**: Make changes in feature branch
2. **PR**: Create PR to main
3. **Validate**: Pipeline runs validation and security scans
4. **Review**: Team reviews plan and security findings
5. **Merge**: Merge to main after approval
6. **Plan**: Pipeline generates plan
7. **Approve**: Manual approval in Azure DevOps
8. **Apply**: Infrastructure changes applied

## Monitoring

After deployment:
```bash
# View outputs
terraform output

# Check resources
aws eks list-clusters
aws rds describe-db-instances
aws elasticache describe-cache-clusters

# Verify state
terraform state list
```

## Rollback

If issues occur:
```bash
# Revert to previous state
terraform state pull > backup.tfstate
terraform state push previous.tfstate

# Or use version control
git revert <commit>
git push
# Pipeline will plan and apply the revert
```
