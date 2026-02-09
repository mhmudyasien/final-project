# Backend Repository - CI/CD Pipeline

This repository contains the backend application with a comprehensive CI/CD pipeline.

## Pipeline Overview

The pipeline consists of 6 stages:

1. **Build & Test**: Unit and integration tests with coverage
2. **Security Scan**: OWASP checks and SonarQube analysis
3. **Build Image**: Docker build, scan, sign, and push to ECR
4. **Deploy Dev**: Automatic deployment to dev environment
5. **Deploy Staging**: Deployment to staging (main branch only)
6. **Deploy Prod**: Production deployment with manual approval

## Triggers

- **CI Trigger**: Runs on push to `main`, `develop`, or `release/*` branches
- **PR Trigger**: Runs on PRs to `main` or `develop`
- **Path Filter**: Only triggers when backend code changes

## Stages

### 1. Build & Test

**Unit Tests:**
- pytest with coverage
- Cached pip dependencies
- Coverage threshold: 80%
- Test results published

**Integration Tests:**
- Service containers: PostgreSQL 14, Redis 7
- Database migrations
- API integration tests
- Automatic cleanup

### 2. Security Scan

**OWASP Dependency Check:**
- Bandit (code security scanner)
- pip-audit (dependency vulnerabilities)
- Safety (dependency security)
- Fails on high-severity issues

**SonarQube Analysis:**
- Code quality metrics
- Security hotspots
- Quality gate enforcement
- Coverage integration

### 3. Build Image

**Docker Build:**
- Multi-stage build with BuildKit
- Layer caching enabled
- Python 3.11 base image

**Trivy Scan:**
- Vulnerability scanning
- Fails on CRITICAL/HIGH
- HTML and JSON reports

**SBOM Generation:**
- SPDX and CycloneDX formats
- Attached to image

**Cosign Signing:**
- Keyless signing with Azure DevOps OIDC
- Signature verification
- Rekor transparency log

**ECR Push:**
- Immutable tags
- Multiple tags: build number, commit SHA, latest
- Image scanning enabled

### 4-6. Deployment Stages

**Dev Environment:**
- Auto-deploy on `develop` branch
- Namespace: `dev`
- Health checks enabled
- Auto-rollback on failure

**Staging Environment:**
- Auto-deploy on `main` branch
- Namespace: `staging`
- Health checks enabled

**Production Environment:**
- Manual approval required
- Namespace: `prod`
- Health checks enabled
- Zero-downtime deployment

## Environment Variables

Set in Azure DevOps Library:
- `AWS_ACCOUNT_ID`: AWS account ID
- `AWS_REGION`: AWS region (default: us-east-2)
- `EKS_CLUSTER_NAME`: EKS cluster name
- `SONARQUBE_URL`: SonarQube server URL

## Service Connections

Required:
- `AWS-ECR-ServiceConnection`: ECR authentication
- `AWS-ServiceConnection`: AWS CLI operations
- `SonarQube-ServiceConnection`: SonarQube integration

## Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run tests
pytest tests/ --cov=.

# Run integration tests (requires Docker)
docker-compose up -d postgres redis
pytest tests/integration/
```

## Pipeline Artifacts

- Test results and coverage reports
- Security scan reports (Bandit, pip-audit, Safety)
- SonarQube analysis results
- Trivy vulnerability reports
- SBOM files (SPDX, CycloneDX)
- Image manifest with digest

## Deployment

The pipeline uses the enhanced `deploy.sh` script with:
- Environment validation
- kubectl connectivity checks
- Health checks with retries
- Automatic rollback on failure

## Monitoring

After deployment, verify:
```bash
# Check pods
kubectl get pods -n <namespace>

# Check deployment status
kubectl rollout status deployment/backend -n <namespace>

# View logs
kubectl logs -f deployment/backend -n <namespace>
```
