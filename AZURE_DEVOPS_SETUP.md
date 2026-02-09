# Azure DevOps Setup Guide

Complete guide to organizing and configuring Azure DevOps for this project.

---

## Table of Contents

1. [Repository Organization](#repository-organization)
2. [Azure DevOps Project Setup](#azure-devops-project-setup)
3. [Service Connections](#service-connections)
4. [Variable Groups](#variable-groups)
5. [Environments](#environments)
6. [Pipeline Setup](#pipeline-setup)
7. [Testing the Setup](#testing-the-setup)
8. [Troubleshooting](#troubleshooting)

---

## Repository Organization

### Option 1: Multi-Repo Setup (Recommended for Production)

Create **4 separate repositories** in Azure DevOps:

```
Azure DevOps Project: final-project
├── Repository: pipeline-templates
│   └── Contains: pipelines/templates/, pipelines/vars/
│
├── Repository: backend
│   └── Contains: backend/, azure-pipelines.yml
│
├── Repository: frontend
│   └── Contains: frontend/, azure-pipelines.yml
│
└── Repository: infrastructure
    └── Contains: terraform/, ansible/, k8s/, azure-pipelines.yml
```

**Benefits:**
- Independent versioning
- Separate permissions
- Cleaner CI/CD triggers
- Better team organization

### Option 2: Monorepo Setup (Simpler for Small Teams)

Use **1 repository** with path-based triggers:

```
Azure DevOps Project: final-project
└── Repository: final-project
    ├── pipelines/           # Shared templates
    ├── backend/             # Backend code + pipeline
    ├── frontend/            # Frontend code + pipeline
    └── infrastructure/      # Terraform + pipeline
```

**Benefits:**
- Simpler to manage
- Single source of truth
- Easier local development

---

## Azure DevOps Project Setup

### Step 1: Create Azure DevOps Organization

1. Go to https://dev.azure.com
2. Click **"New organization"**
3. Name: `your-org-name`
4. Region: Choose closest to your AWS region

### Step 2: Create Project

1. Click **"New project"**
2. Name: `final-project`
3. Visibility: **Private**
4. Version control: **Git**
5. Work item process: **Agile**

### Step 3: Create Repositories

#### For Multi-Repo Setup:

1. **Create pipeline-templates repo:**
   ```bash
   cd /home/mahmoud/Desktop/final-project
   
   # Initialize and push pipeline templates
   cd pipelines
   git init
   git remote add origin https://dev.azure.com/your-org/final-project/_git/pipeline-templates
   git add .
   git commit -m "Initial pipeline templates"
   git push -u origin main
   ```

2. **Create backend repo:**
   ```bash
   cd /home/mahmoud/Desktop/final-project
   
   # Copy backend files
   mkdir -p /tmp/backend-repo
   cp -r backend/* /tmp/backend-repo/
   cp backend-repo/azure-pipelines.yml /tmp/backend-repo/
   
   cd /tmp/backend-repo
   git init
   git remote add origin https://dev.azure.com/your-org/final-project/_git/backend
   git add .
   git commit -m "Initial backend setup"
   git push -u origin main
   ```

3. **Create frontend repo:**
   ```bash
   # Similar to backend
   mkdir -p /tmp/frontend-repo
   cp -r frontend/* /tmp/frontend-repo/
   cp frontend-repo/azure-pipelines.yml /tmp/frontend-repo/
   
   cd /tmp/frontend-repo
   git init
   git remote add origin https://dev.azure.com/your-org/final-project/_git/frontend
   git add .
   git commit -m "Initial frontend setup"
   git push -u origin main
   ```

4. **Create infrastructure repo:**
   ```bash
   mkdir -p /tmp/infrastructure-repo
   cp -r terraform ansible k8s /tmp/infrastructure-repo/
   cp infra-repo/azure-pipelines.yml /tmp/infrastructure-repo/
   
   cd /tmp/infrastructure-repo
   git init
   git remote add origin https://dev.azure.com/your-org/final-project/_git/infrastructure
   git add .
   git commit -m "Initial infrastructure setup"
   git push -u origin main
   ```

#### For Monorepo Setup:

```bash
cd /home/mahmoud/Desktop/final-project
git init
git remote add origin https://dev.azure.com/your-org/final-project/_git/final-project
git add .
git commit -m "Initial project setup"
git push -u origin main
```

---

## Service Connections

### 1. AWS Service Connection (for AWS CLI operations)

**Navigate to:** Project Settings → Service connections → New service connection

**Type:** AWS

**Configuration:**
- **Connection name:** `AWS-ServiceConnection`
- **Access Key ID:** Your AWS access key
- **Secret Access Key:** Your AWS secret key
- **Grant access permission to all pipelines:** ✅ (or configure per-pipeline)

**Alternative (More Secure):** Use AWS IAM Role with OIDC
- Follow: https://docs.microsoft.com/en-us/azure/devops/pipelines/library/connect-to-azure

### 2. AWS ECR Service Connection (for Docker operations)

**Type:** Docker Registry

**Configuration:**
- **Connection name:** `AWS-ECR-ServiceConnection`
- **Registry type:** Others
- **Docker Registry:** `https://$(AWS_ACCOUNT_ID).dkr.ecr.us-east-2.amazonaws.com`
- **Docker ID:** `AWS`
- **Docker Password:** Run this command to get token:
  ```bash
  aws ecr get-login-password --region us-east-2
  ```
  ⚠️ **Note:** ECR tokens expire after 12 hours. Consider using a service principal or automated token refresh.

**Better Alternative:** Use AWS task in pipeline to login to ECR
```yaml
- task: AWSCLI@1
  inputs:
    awsCredentials: 'AWS-ServiceConnection'
    regionName: 'us-east-2'
    awsCommand: 'ecr'
    awsSubCommand: 'get-login-password'
```

### 3. SonarQube Service Connection

**Type:** SonarQube

**Configuration:**
- **Connection name:** `SonarQube-ServiceConnection`
- **Server URL:** Your SonarQube URL (e.g., `http://your-sonarqube-server:9000`)
- **Token:** Generate in SonarQube: My Account → Security → Generate Token

**SonarQube Setup:**
1. Install SonarQube (Docker recommended):
   ```bash
   docker run -d --name sonarqube \
     -p 9000:9000 \
     -v sonarqube_data:/opt/sonarqube/data \
     -v sonarqube_logs:/opt/sonarqube/logs \
     -v sonarqube_extensions:/opt/sonarqube/extensions \
     sonarqube:community
   ```

2. Access: http://localhost:9000
3. Default credentials: admin/admin (change immediately)
4. Create projects for backend and frontend

---

## Variable Groups

### Create Variable Group

**Navigate to:** Pipelines → Library → + Variable group

### Variable Group: `common-variables`

**Variables:**

| Name | Value | Secret? | Description |
|------|-------|---------|-------------|
| `aws-account-id` | Your AWS account ID | ❌ | AWS Account ID |
| `eks-cluster-name` | `final-project-cluster` | ❌ | EKS cluster name |
| `sonarqube-url` | `http://your-sonarqube:9000` | ❌ | SonarQube server URL |
| `AWS_REGION` | `us-east-2` | ❌ | AWS region |

**Link to Pipelines:**
- ✅ Allow access to all pipelines (or configure per-pipeline)

### Additional Variable Groups (Optional)

**Environment-Specific Variables:**

Create separate groups for dev/staging/prod:
- `dev-variables`
- `staging-variables`
- `prod-variables`

---

## Environments

### Create Environments for Deployment Approvals

**Navigate to:** Pipelines → Environments → New environment

### 1. Development Environment

- **Name:** `dev`
- **Description:** Development environment
- **Approvals:** None (auto-deploy)

### 2. Staging Environment

- **Name:** `staging`
- **Description:** Staging environment
- **Approvals:** Optional (configure if needed)

**To add approval:**
1. Click environment → ⋮ → Approvals and checks
2. Add → Approvals
3. Select approvers

### 3. Production Environment

- **Name:** `production`
- **Description:** Production environment
- **Approvals:** ✅ **Required**

**Configure approval:**
1. Click `production` → ⋮ → Approvals and checks
2. Add → Approvals
3. **Approvers:** Select team leads/managers
4. **Timeout:** 30 days
5. **Instructions:** "Review deployment plan before approving"

### 4. Infrastructure Environment

- **Name:** `infrastructure`
- **Description:** Infrastructure changes (Terraform)
- **Approvals:** ✅ **Required**

---

## Pipeline Setup

### Multi-Repo Setup

#### 1. Backend Pipeline

**Navigate to:** Pipelines → New pipeline

1. **Where is your code?** → Azure Repos Git
2. **Select repository:** `backend`
3. **Configure:** Existing Azure Pipelines YAML file
4. **Path:** `/azure-pipelines.yml`
5. **Update pipeline YAML** to reference templates repo:

```yaml
resources:
  repositories:
    - repository: templates
      type: git
      name: final-project/pipeline-templates
      ref: refs/heads/main

# Then use templates like:
- template: templates/docker/build-docker.yml@templates
  parameters:
    imageName: 'fastapi-backend'
```

6. **Save and run**

#### 2. Frontend Pipeline

Same process as backend:
1. Create pipeline for `frontend` repo
2. Reference templates repo
3. Update template paths to use `@templates`

#### 3. Infrastructure Pipeline

Same process for `infrastructure` repo.

### Monorepo Setup

#### Single Pipeline with Path Triggers

1. **Create pipeline:** Pipelines → New pipeline
2. **Select:** `final-project` repo
3. **Configure:** Existing Azure Pipelines YAML file
4. **Create 3 separate pipelines:**
   - Backend: `/backend-repo/azure-pipelines.yml`
   - Frontend: `/frontend-repo/azure-pipelines.yml`
   - Infrastructure: `/infra-repo/azure-pipelines.yml`

5. **Update template references** (templates are in same repo):

```yaml
# In backend-repo/azure-pipelines.yml
- template: ../pipelines/templates/docker/build-docker.yml
  parameters:
    imageName: 'fastapi-backend'
```

---

## Pipeline Configuration Updates

### For Multi-Repo: Update Template References

**In each pipeline (backend, frontend, infrastructure):**

```yaml
# Add at the top
resources:
  repositories:
    - repository: templates
      type: git
      name: final-project/pipeline-templates
      ref: refs/heads/main

# Update all template references
- template: templates/docker/build-docker.yml@templates  # Add @templates
  parameters:
    imageName: 'fastapi-backend'
```

### For Monorepo: Update Paths

**Ensure paths are correct relative to pipeline location:**

```yaml
# backend-repo/azure-pipelines.yml
- template: ../pipelines/templates/docker/build-docker.yml
  parameters:
    imageName: 'fastapi-backend'
```

---

## Testing the Setup

### 1. Test Service Connections

```bash
# Test AWS connection
az pipelines run --name "backend-pipeline" --branch main

# Check logs for AWS authentication
```

### 2. Test Variable Groups

**Create a test pipeline:**

```yaml
trigger: none

pool:
  vmImage: 'ubuntu-latest'

variables:
  - group: common-variables

steps:
  - script: |
      echo "AWS Account: $(aws-account-id)"
      echo "EKS Cluster: $(eks-cluster-name)"
      echo "Region: $(AWS_REGION)"
    displayName: 'Test Variables'
```

### 3. Test Template Resolution

**Run backend pipeline and check:**
- Templates are found
- No path resolution errors
- All steps execute

### 4. Test Deployment

**Deploy to dev environment:**
1. Merge to `develop` branch
2. Pipeline should auto-deploy to dev
3. Check EKS: `kubectl get pods -n dev`

---

## Pipeline Execution Flow

### Backend/Frontend Pipeline Flow

```
Trigger (push to main/develop)
    ↓
Build & Test Stage
    ├── Unit Tests (with caching)
    └── Integration Tests (service containers)
    ↓
Security Scan Stage (parallel)
    ├── OWASP Dependency Check
    └── SonarQube Analysis
    ↓
Build Image Stage
    ├── Docker Build (with caching)
    ├── Trivy Scan
    ├── SBOM Generation
    ├── Cosign Signing (keyless)
    └── ECR Push
    ↓
Deploy Dev (auto on develop branch)
    ├── kubectl configure
    ├── Apply manifests
    ├── Health checks
    └── Rollback on failure
    ↓
Deploy Staging (auto on main branch)
    ├── Same as dev
    └── More replicas
    ↓
Deploy Prod (manual approval on main)
    ├── Wait for approval
    ├── Deploy with zero-downtime
    └── Health checks
```

### Infrastructure Pipeline Flow

```
Trigger (push to main/develop)
    ↓
Validate Stage
    ├── terraform fmt check
    ├── terraform validate
    └── tflint
    ↓
Security Scan Stage
    ├── Checkov
    └── tfsec
    ↓
Plan Stage
    ├── terraform init
    ├── terraform plan
    └── Publish plan artifact
    ↓
Apply Stage (manual approval on main)
    ├── Wait for approval
    ├── terraform apply
    └── Publish outputs
```

---

## Troubleshooting

### Issue: Templates Not Found

**Error:** `Template file not found: templates/docker/build-docker.yml`

**Solution:**
1. Check repository resource is defined:
   ```yaml
   resources:
     repositories:
       - repository: templates
         type: git
         name: final-project/pipeline-templates
   ```

2. Use `@templates` suffix:
   ```yaml
   - template: templates/docker/build-docker.yml@templates
   ```

### Issue: AWS Authentication Failed

**Error:** `Unable to locate credentials`

**Solution:**
1. Verify service connection: Project Settings → Service connections
2. Check connection name matches pipeline: `AWS-ServiceConnection`
3. Test connection: Edit → Verify

### Issue: ECR Login Failed

**Error:** `Error response from daemon: Get https://xxx.dkr.ecr.us-east-2.amazonaws.com/v2/: no basic auth credentials`

**Solution:**
Use AWS CLI to login in pipeline:
```yaml
- task: AWSCLI@1
  displayName: 'ECR Login'
  inputs:
    awsCredentials: 'AWS-ServiceConnection'
    regionName: '$(AWS_REGION)'
    awsCommand: 'ecr'
    awsSubCommand: 'get-login-password'
    awsArguments: '--region $(AWS_REGION) | docker login --username AWS --password-stdin $(aws-account-id).dkr.ecr.$(AWS_REGION).amazonaws.com'
```

### Issue: Cosign Signing Failed

**Error:** `COSIGN_EXPERIMENTAL must be set`

**Solution:**
Ensure environment variable is set:
```yaml
env:
  COSIGN_EXPERIMENTAL: 1
  SYSTEM_ACCESSTOKEN: $(System.AccessToken)
```

### Issue: Deployment Health Checks Timeout

**Error:** `Deployment did not complete within 300 seconds`

**Solution:**
1. Increase timeout:
   ```yaml
   parameters:
     healthCheckTimeout: 600  # 10 minutes
   ```

2. Check pod logs:
   ```bash
   kubectl logs -f deployment/backend -n dev
   ```

3. Check events:
   ```bash
   kubectl get events -n dev --sort-by='.lastTimestamp'
   ```

---

## Best Practices

### 1. Branch Strategy

**Recommended:**
- `main` → Production
- `develop` → Development
- `feature/*` → Feature branches
- `release/*` → Release candidates

### 2. Pipeline Triggers

**Configure triggers to avoid unnecessary runs:**

```yaml
trigger:
  branches:
    include:
      - main
      - develop
  paths:
    include:
      - backend/*
    exclude:
      - '**/*.md'
      - docs/*
```

### 3. Secrets Management

**Never commit secrets!**

Use:
- Azure Key Vault integration
- Variable groups with secret variables
- Service connections

### 4. Pipeline Caching

**Already implemented in templates:**
- pip cache: `$(Pipeline.Workspace)/.pip`
- npm cache: `$(Pipeline.Workspace)/.npm`
- Docker layer cache: ECR

### 5. Monitoring

**Set up notifications:**
1. Project Settings → Notifications
2. Create subscription for:
   - Build failures
   - Deployment failures
   - Approval requests

---

## Quick Start Checklist

- [ ] Create Azure DevOps organization and project
- [ ] Create repositories (4 repos or 1 monorepo)
- [ ] Push code to repositories
- [ ] Create service connections (AWS, ECR, SonarQube)
- [ ] Create variable group `common-variables`
- [ ] Create environments (dev, staging, production, infrastructure)
- [ ] Configure production approval
- [ ] Create pipelines (backend, frontend, infrastructure)
- [ ] Update template references (if multi-repo)
- [ ] Test pipeline execution
- [ ] Verify deployment to dev
- [ ] Document any custom configurations

---

## Support Resources

- [Azure Pipelines Documentation](https://docs.microsoft.com/en-us/azure/devops/pipelines/)
- [YAML Schema Reference](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema)
- [Service Connections](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints)
- [Environments](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/environments)
