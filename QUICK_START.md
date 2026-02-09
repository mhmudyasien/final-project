# Azure DevOps Quick Reference

## Repository Organization (Recommended: Multi-Repo)

```
┌─────────────────────────────────────────────────────────────┐
│ Azure DevOps Organization: your-org-name                    │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Project: final-project                                 │ │
│  │                                                        │ │
│  │  Repositories:                                         │ │
│  │  ├── pipeline-templates (shared templates)            │ │
│  │  ├── backend (FastAPI application)                    │ │
│  │  ├── frontend (React application)                     │ │
│  │  └── infrastructure (Terraform/K8s/Ansible)           │ │
│  │                                                        │ │
│  │  Service Connections:                                  │ │
│  │  ├── AWS-ServiceConnection                            │ │
│  │  ├── AWS-ECR-ServiceConnection                        │ │
│  │  └── SonarQube-ServiceConnection                      │ │
│  │                                                        │ │
│  │  Variable Groups:                                      │ │
│  │  └── common-variables                                 │ │
│  │      ├── aws-account-id                               │ │
│  │      ├── eks-cluster-name                             │ │
│  │      ├── sonarqube-url                                │ │
│  │      └── AWS_REGION                                   │ │
│  │                                                        │ │
│  │  Environments:                                         │ │
│  │  ├── dev (no approval)                                │ │
│  │  ├── staging (optional approval)                      │ │
│  │  ├── production (manual approval required) ⚠️         │ │
│  │  └── infrastructure (manual approval required) ⚠️     │ │
│  │                                                        │ │
│  │  Pipelines:                                            │ │
│  │  ├── Backend CI/CD                                    │ │
│  │  ├── Frontend CI/CD                                   │ │
│  │  └── Infrastructure (Terraform)                       │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Setup Steps (In Order)

### 1️⃣ Create Azure DevOps Project
- Go to https://dev.azure.com
- Create organization → Create project

### 2️⃣ Create Repositories
**Option A: Multi-Repo (Recommended)**
```bash
# 1. Pipeline templates
cd pipelines
git init && git remote add origin https://dev.azure.com/org/project/_git/pipeline-templates
git push -u origin main

# 2. Backend
# Copy backend code + backend-repo/azure-pipelines.yml
git init && git remote add origin https://dev.azure.com/org/project/_git/backend
git push -u origin main

# 3. Frontend
# Copy frontend code + frontend-repo/azure-pipelines.yml
git init && git remote add origin https://dev.azure.com/org/project/_git/frontend
git push -u origin main

# 4. Infrastructure
# Copy terraform, ansible, k8s + infra-repo/azure-pipelines.yml
git init && git remote add origin https://dev.azure.com/org/project/_git/infrastructure
git push -u origin main
```

**Option B: Monorepo (Simpler)**
```bash
cd /home/mahmoud/Desktop/final-project
git init
git remote add origin https://dev.azure.com/org/project/_git/final-project
git push -u origin main
```

### 3️⃣ Create Service Connections
**Project Settings → Service connections**

| Name | Type | Configuration |
|------|------|---------------|
| AWS-ServiceConnection | AWS | Access Key + Secret |
| AWS-ECR-ServiceConnection | Docker Registry | ECR URL + credentials |
| SonarQube-ServiceConnection | SonarQube | URL + token |

### 4️⃣ Create Variable Group
**Pipelines → Library → + Variable group**

Name: `common-variables`

| Variable | Value | Secret? |
|----------|-------|---------|
| aws-account-id | Your AWS account ID | No |
| eks-cluster-name | final-project-cluster | No |
| sonarqube-url | http://your-sonarqube:9000 | No |
| AWS_REGION | us-east-2 | No |

✅ Allow access to all pipelines

### 5️⃣ Create Environments
**Pipelines → Environments**

| Environment | Approvals Required? |
|-------------|---------------------|
| dev | ❌ No |
| staging | ⚠️ Optional |
| production | ✅ **Yes** |
| infrastructure | ✅ **Yes** |

### 6️⃣ Create Pipelines
**Pipelines → New pipeline**

**For Multi-Repo:**
1. Create pipeline for each repo (backend, frontend, infrastructure)
2. Select "Existing Azure Pipelines YAML file"
3. Path: `/azure-pipelines.yml`
4. **Important:** Add repository resource in each pipeline:
   ```yaml
   resources:
     repositories:
       - repository: templates
         type: git
         name: final-project/pipeline-templates
         ref: refs/heads/main
   ```
5. Update template references: `@templates` suffix

**For Monorepo:**
1. Create 3 separate pipelines pointing to:
   - `/backend-repo/azure-pipelines.yml`
   - `/frontend-repo/azure-pipelines.yml`
   - `/infra-repo/azure-pipelines.yml`

### 7️⃣ Test
1. Push to `develop` branch → Should deploy to dev
2. Push to `main` branch → Should deploy to staging, wait for prod approval
3. Check pipeline logs for any errors

---

## Pipeline Template References

### Multi-Repo Setup
```yaml
# In backend/frontend/infrastructure pipelines
resources:
  repositories:
    - repository: templates
      type: git
      name: final-project/pipeline-templates
      ref: refs/heads/main

# Use templates with @templates suffix
- template: templates/docker/build-docker.yml@templates
  parameters:
    imageName: 'my-app'
```

### Monorepo Setup
```yaml
# In backend-repo/azure-pipelines.yml
- template: ../pipelines/templates/docker/build-docker.yml
  parameters:
    imageName: 'my-app'
```

---

## Common Issues & Solutions

### ❌ Templates Not Found
**Error:** `Template file not found`

**Fix:** Add `@templates` suffix for multi-repo:
```yaml
- template: templates/docker/build-docker.yml@templates
```

### ❌ AWS Authentication Failed
**Error:** `Unable to locate credentials`

**Fix:** 
1. Verify service connection exists
2. Check connection name matches: `AWS-ServiceConnection`
3. Test connection in Project Settings

### ❌ ECR Login Failed
**Error:** `no basic auth credentials`

**Fix:** Use AWS CLI task to login:
```yaml
- task: AWSCLI@1
  inputs:
    awsCredentials: 'AWS-ServiceConnection'
    regionName: '$(AWS_REGION)'
    awsCommand: 'ecr'
    awsSubCommand: 'get-login-password'
```

### ❌ Variable Not Found
**Error:** `$(aws-account-id) could not be found`

**Fix:**
1. Add variable group to pipeline:
   ```yaml
   variables:
     - group: common-variables
   ```
2. Verify variable group name is correct

---

## Deployment Flow

```
Developer pushes to develop branch
    ↓
Backend/Frontend Pipeline Triggered
    ↓
Build & Test (unit + integration)
    ↓
Security Scan (OWASP + SonarQube)
    ↓
Build Docker Image
    ↓
Scan with Trivy
    ↓
Generate SBOM
    ↓
Sign with Cosign (keyless)
    ↓
Push to ECR
    ↓
Deploy to Dev (automatic)
    ↓
Health Checks
    ↓
✅ Success or ❌ Rollback
```

```
Developer pushes to main branch
    ↓
Pipeline runs all stages
    ↓
Deploy to Staging (automatic)
    ↓
⏸️ Wait for Production Approval
    ↓
👤 Team Lead Approves
    ↓
Deploy to Production
    ↓
Health Checks
    ↓
✅ Success or ❌ Rollback
```

---

## Next Steps After Setup

1. ✅ Verify all pipelines run successfully
2. ✅ Test deployment to dev environment
3. ✅ Configure branch policies (require PR for main)
4. ✅ Set up notifications for build failures
5. ✅ Document any custom configurations
6. ✅ Train team on pipeline usage

---

## Support

- Full setup guide: [AZURE_DEVOPS_SETUP.md](file:///home/mahmoud/Desktop/final-project/AZURE_DEVOPS_SETUP.md)
- Pipeline templates: [pipelines/README.md](file:///home/mahmoud/Desktop/final-project/pipelines/README.md)
- Walkthrough: [walkthrough.md](file:///home/mahmoud/.gemini/antigravity/brain/8c8365a5-ffe9-44ef-803f-d4c818c0d447/walkthrough.md)
