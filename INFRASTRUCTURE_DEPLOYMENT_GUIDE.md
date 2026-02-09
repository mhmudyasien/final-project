# 🚀 Complete Infrastructure Deployment Guide

**Step-by-step guide to deploy the entire infrastructure from scratch**

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Deployment Order](#deployment-order)
3. [Step-by-Step Instructions](#step-by-step-instructions)
4. [Script Explanations](#script-explanations)
5. [Verification Steps](#verification-steps)
6. [Troubleshooting](#troubleshooting)
7. [Project Explanation for Presentation](#project-explanation-for-presentation)

---

## Prerequisites

### Required Tools

Install these before starting:

```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Ansible
sudo apt update
sudo apt install -y ansible
```

### AWS Configuration

```bash
# Configure AWS credentials
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: us-east-2
# - Default output format: json

# Verify
aws sts get-caller-identity
```

---

## 🎯 Deployment Order

**CRITICAL: Follow this exact order!**

```
1. Terraform (Infrastructure)
   ├── VPC, Subnets, NAT Gateway
   ├── EKS Cluster
   ├── RDS Database
   ├── ElastiCache Redis
   └── Vault EC2 Instance

2. Vault Setup (Secrets Management)
   ├── Initialize Vault
   ├── Configure Kubernetes Auth
   └── Store Database Credentials

3. Kubernetes Setup (Application Platform)
   ├── Configure kubectl
   ├── Install AWS Load Balancer Controller
   ├── Install Kyverno (Policy Engine)
   └── Deploy Vault Injector

4. Application Deployment
   ├── Build & Push Docker Images
   └── Deploy Backend & Frontend

5. Monitoring & Security
   ├── CloudWatch Container Insights
   └── Kyverno Policies
```

---

## 📖 Step-by-Step Instructions

### Phase 1: Infrastructure Provisioning (Terraform)

**Estimated Time:** 20-30 minutes

```bash
# Navigate to terraform directory
cd terraform/

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply infrastructure
terraform apply -auto-approve

# IMPORTANT: Save outputs
terraform output > ../terraform-outputs.txt

# Get important values
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
export VAULT_PUBLIC_IP=$(terraform output -raw vault_public_ip)
export RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
export REDIS_ENDPOINT=$(terraform output -raw redis_endpoint)

# Save these to a file for later use
cat > ../config-values.txt <<EOF
AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID
EKS_CLUSTER_NAME=$EKS_CLUSTER_NAME
VAULT_PUBLIC_IP=$VAULT_PUBLIC_IP
RDS_ENDPOINT=$RDS_ENDPOINT
REDIS_ENDPOINT=$REDIS_ENDPOINT
EOF

echo "✅ Infrastructure provisioned successfully!"
```

**What was created:**
- ✅ VPC with public/private subnets across 2 AZs
- ✅ EKS cluster with managed node group
- ✅ RDS PostgreSQL database
- ✅ ElastiCache Redis cluster
- ✅ Vault EC2 instance
- ✅ Security groups and IAM roles

---

### Phase 2: Vault Setup (Secrets Management)

**Estimated Time:** 10-15 minutes

#### Step 2.1: Run Vault Setup Script

```bash
# Go back to project root
cd ..

# Make scripts executable
chmod +x run-vault-setup.sh run-vault-config.sh

# Run Vault setup (initializes and unseals Vault)
./run-vault-setup.sh

# This script will:
# 1. SSH into Vault EC2 instance
# 2. Initialize Vault (creates unseal keys)
# 3. Unseal Vault
# 4. Enable secrets engine
# 5. Save root token and unseal keys to vault-init-keys.json

# IMPORTANT: Backup vault-init-keys.json securely!
# This file contains your Vault root token and unseal keys
cp vault-init-keys.json ~/vault-backup-$(date +%Y%m%d).json

echo "✅ Vault initialized and unsealed!"
```

#### Step 2.2: Configure Vault for Kubernetes

```bash
# Run Vault configuration script
./run-vault-config.sh

# This script will:
# 1. Configure Kubernetes authentication
# 2. Create policies for webapp access
# 3. Create Kubernetes role
# 4. Store database credentials in Vault
# 5. Save authentication token

echo "✅ Vault configured for Kubernetes!"
```

**What was configured:**
- ✅ Vault initialized with 5 unseal keys
- ✅ Kubernetes auth method enabled
- ✅ Database credentials stored securely
- ✅ Policies created for application access

---

### Phase 3: Kubernetes Setup

**Estimated Time:** 15-20 minutes

#### Step 3.1: Configure kubectl

```bash
# Update kubeconfig for EKS
aws eks update-kubeconfig \
  --name $EKS_CLUSTER_NAME \
  --region us-east-2

# Verify connection
kubectl get nodes

# Should show 2 nodes in Ready state
```

#### Step 3.2: Install AWS Load Balancer Controller

```bash
# Run installation script
chmod +x install-alb-controller.sh
./install-alb-controller.sh

# Or manually:
# 1. Create IAM policy
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam-policy.json

# 2. Create service account
eksctl create iamserviceaccount \
  --cluster=$EKS_CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# 3. Install controller with Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$EKS_CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Verify
kubectl get deployment -n kube-system aws-load-balancer-controller

echo "✅ ALB Controller installed!"
```

#### Step 3.3: Install Kyverno (Policy Engine)

```bash
# Run installation script
chmod +x install-kyverno.sh
./install-kyverno.sh

# Or manually:
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

helm install kyverno kyverno/kyverno \
  -n kyverno --create-namespace \
  -f k8s/kyverno/kyverno-values.yaml

# Apply policies
kubectl apply -f k8s/kyverno/policies/

# Verify
kubectl get clusterpolicy

echo "✅ Kyverno installed and policies applied!"
```

#### Step 3.4: Install Vault Injector

```bash
# Run installation script
chmod +x install-vault-injector.sh
./install-vault-injector.sh

# This installs Vault Agent Injector for automatic secret injection

# Verify
kubectl get pods -n vault

echo "✅ Vault Injector installed!"
```

#### Step 3.5: Create Namespaces

```bash
# Create application namespaces
kubectl apply -f k8s/dev/namespace.yaml
kubectl apply -f k8s/staging/namespace.yaml
kubectl apply -f k8s/prod/namespace.yaml

# Verify
kubectl get namespaces

echo "✅ Namespaces created!"
```

---

### Phase 4: Application Deployment

**Estimated Time:** 10-15 minutes

#### Step 4.1: Build and Push Docker Images

```bash
# Run build and push script
chmod +x build-and-push.sh
./build-and-push.sh

# This script will:
# 1. Login to ECR
# 2. Build backend Docker image
# 3. Build frontend Docker image
# 4. Tag images with version
# 5. Push to ECR

# Or manually:
# Login to ECR
aws ecr get-login-password --region us-east-2 | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.us-east-2.amazonaws.com

# Build backend
cd backend
docker build -t fastapi-backend:latest .
docker tag fastapi-backend:latest \
  $AWS_ACCOUNT_ID.dkr.ecr.us-east-2.amazonaws.com/fastapi-backend:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-2.amazonaws.com/fastapi-backend:latest

# Build frontend
cd ../frontend
docker build -t react-frontend:latest .
docker tag react-frontend:latest \
  $AWS_ACCOUNT_ID.dkr.ecr.us-east-2.amazonaws.com/react-frontend:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-2.amazonaws.com/react-frontend:latest

cd ..

echo "✅ Docker images built and pushed!"
```

#### Step 4.2: Deploy Applications

```bash
# Run deployment script
chmod +x deploy.sh
./deploy.sh dev

# This will deploy to dev environment
# Use: ./deploy.sh staging  or  ./deploy.sh prod  for other environments

# Or manually:
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-2
export IMAGE_TAG=latest

# Deploy to dev
envsubst < k8s/dev/backend-deployment.yaml | kubectl apply -f -
envsubst < k8s/dev/backend-service.yaml | kubectl apply -f -
envsubst < k8s/dev/frontend-deployment.yaml | kubectl apply -f -
envsubst < k8s/dev/frontend-service.yaml | kubectl apply -f -
envsubst < k8s/dev/ingress.yaml | kubectl apply -f -

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=backend -n dev --timeout=300s
kubectl wait --for=condition=ready pod -l app=frontend -n dev --timeout=300s

echo "✅ Applications deployed!"
```

#### Step 4.3: Get Application URL

```bash
# Get ALB DNS name
kubectl get ingress -n dev

# Or
ALB_URL=$(kubectl get ingress application-ingress -n dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Application URL: http://$ALB_URL"

# Test
curl http://$ALB_URL/api/health

echo "✅ Application accessible!"
```

---

### Phase 5: Monitoring & Security

**Estimated Time:** 10 minutes

#### Step 5.1: Install CloudWatch Container Insights

```bash
# Install CloudWatch agent and Fluent Bit
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml

# Verify
kubectl get pods -n amazon-cloudwatch

echo "✅ CloudWatch Container Insights installed!"
```

#### Step 5.2: Verify Kyverno Policies

```bash
# Check policy reports
kubectl get policyreport -A

# View specific policy
kubectl describe clusterpolicy verify-ecr-signed-images

echo "✅ Kyverno policies active!"
```

---

## 📝 Script Explanations

### 1. `run-vault-setup.sh`

**Purpose:** Initialize and unseal Vault on EC2 instance

**What it does:**
1. SSHs into Vault EC2 instance
2. Runs Ansible playbook `vault-setup.yml`
3. Initializes Vault (generates 5 unseal keys + root token)
4. Unseals Vault using 3 of the 5 keys
5. Enables KV secrets engine
6. Saves keys to `vault-init-keys.json`

**When to run:** After Terraform creates infrastructure (Phase 2.1)

**Output:** `vault-init-keys.json` with root token and unseal keys

---

### 2. `run-vault-config.sh`

**Purpose:** Configure Vault for Kubernetes authentication

**What it does:**
1. SSHs into Vault EC2 instance
2. Runs Ansible playbook `vault-config.yml`
3. Enables Kubernetes auth method
4. Creates policies for webapp access
5. Creates Kubernetes role bound to service account
6. Stores database credentials in Vault
7. Saves auth token to `vault_auth_token.txt`

**When to run:** After `run-vault-setup.sh` (Phase 2.2)

**Output:** `vault_auth_token.txt` with authentication token

---

### 3. `build-and-push.sh`

**Purpose:** Build Docker images and push to ECR

**What it does:**
1. Logs into AWS ECR
2. Builds backend Docker image from `backend/Dockerfile`
3. Builds frontend Docker image from `frontend/Dockerfile`
4. Tags images with version (latest or specific tag)
5. Pushes images to ECR repositories

**When to run:** After ECR repositories are created (Phase 4.1)

**Output:** Docker images in ECR

---

### 4. `deploy.sh`

**Purpose:** Deploy applications to Kubernetes

**What it does:**
1. Takes environment as argument (dev/staging/prod)
2. Substitutes environment variables in K8s manifests
3. Applies deployments, services, and ingress
4. Waits for pods to be ready
5. Displays application URL

**When to run:** After Docker images are pushed (Phase 4.2)

**Usage:** `./deploy.sh dev` or `./deploy.sh prod`

**Output:** Running application in EKS

---

### 5. `install-kyverno.sh`

**Purpose:** Install Kyverno policy engine

**What it does:**
1. Adds Kyverno Helm repository
2. Installs Kyverno with custom values
3. Applies security policies
4. Verifies installation

**When to run:** After EKS cluster is ready (Phase 3.3)

**Output:** Kyverno running in cluster with policies active

---

### 6. `install-vault-injector.sh`

**Purpose:** Install Vault Agent Injector

**What it does:**
1. Adds HashiCorp Helm repository
2. Installs Vault Agent Injector
3. Configures connection to Vault server
4. Creates Kubernetes auth RBAC

**When to run:** After Vault is configured (Phase 3.4)

**Output:** Vault injector running, ready to inject secrets

---

### 7. `get-config-values.sh`

**Purpose:** Extract configuration values from Terraform

**What it does:**
1. Reads Terraform outputs
2. Exports environment variables
3. Saves to file for reuse

**When to run:** After Terraform apply (Phase 1)

**Output:** Configuration file with all values

---

## ✅ Verification Steps

### Check Infrastructure

```bash
# Terraform
cd terraform && terraform show

# EKS Cluster
aws eks describe-cluster --name $EKS_CLUSTER_NAME

# RDS Database
aws rds describe-db-instances --db-instance-identifier final-project-db

# ElastiCache
aws elasticache describe-cache-clusters --cache-cluster-id final-project-redis
```

### Check Vault

```bash
# SSH to Vault
ssh -i ~/.ssh/vault-key.pem ubuntu@$VAULT_PUBLIC_IP

# Check status
vault status

# List secrets
vault kv list secret/
```

### Check Kubernetes

```bash
# Nodes
kubectl get nodes

# Pods
kubectl get pods -A

# Services
kubectl get svc -A

# Ingress
kubectl get ingress -A
```

### Check Application

```bash
# Get URL
ALB_URL=$(kubectl get ingress application-ingress -n dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test backend
curl http://$ALB_URL/api/health

# Test frontend
curl http://$ALB_URL/
```

---

## 🐛 Troubleshooting

### Terraform Issues

**Error: Insufficient capacity**
```bash
# Change instance type in terraform/variables.tf
# From: t3.medium
# To: t3.small or t2.medium
```

**Error: VPC limit exceeded**
```bash
# Delete unused VPCs
aws ec2 describe-vpcs
aws ec2 delete-vpc --vpc-id vpc-xxxxx
```

### Vault Issues

**Error: Vault sealed**
```bash
# Unseal manually
vault operator unseal <key1>
vault operator unseal <key2>
vault operator unseal <key3>
```

**Error: Cannot connect to Vault**
```bash
# Check security group allows port 8200
# Check Vault is running
ssh ubuntu@$VAULT_PUBLIC_IP "systemctl status vault"
```

### Kubernetes Issues

**Pods not starting**
```bash
# Check logs
kubectl logs -f <pod-name> -n dev

# Describe pod
kubectl describe pod <pod-name> -n dev

# Check events
kubectl get events -n dev --sort-by='.lastTimestamp'
```

**Image pull errors**
```bash
# Verify ECR login
aws ecr get-login-password --region us-east-2

# Check image exists
aws ecr describe-images --repository-name fastapi-backend
```

---

## 🎓 Project Explanation for Presentation

### High-Level Overview

**"This is a production-grade, cloud-native application infrastructure deployed on AWS with enterprise security and DevOps best practices."**

### Architecture Components

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                           │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                   │ │
│  │  ┌──────────────┐         ┌──────────────┐            │ │
│  │  │Public Subnet │         │Public Subnet │            │ │
│  │  │  10.0.1.0/24 │         │  10.0.2.0/24 │            │ │
│  │  │              │         │              │            │ │
│  │  │  NAT Gateway │         │  NAT Gateway │            │ │
│  │  │  Vault EC2   │         │              │            │ │
│  │  └──────┬───────┘         └──────┬───────┘            │ │
│  │         │                        │                    │ │
│  │  ┌──────▼──────────────────────▼───────┐             │ │
│  │  │      Application Load Balancer      │             │ │
│  │  └──────┬──────────────────────────────┘             │ │
│  │         │                                             │ │
│  │  ┌──────▼───────┐         ┌──────────────┐           │ │
│  │  │Private Subnet│         │Private Subnet│           │ │
│  │  │ 10.0.11.0/24 │         │ 10.0.12.0/24 │           │ │
│  │  │              │         │              │           │ │
│  │  │ ┌──────────┐ │         │ ┌──────────┐ │           │ │
│  │  │ │EKS Nodes │ │         │ │EKS Nodes │ │           │ │
│  │  │ │Backend   │ │         │ │Frontend  │ │           │ │
│  │  │ │Frontend  │ │         │ │Backend   │ │           │ │
│  │  │ └──────────┘ │         │ └──────────┘ │           │ │
│  │  │              │         │              │           │ │
│  │  │ ┌──────────┐ │         │ ┌──────────┐ │           │ │
│  │  │ │   RDS    │ │         │ │  Redis   │ │           │ │
│  │  │ │PostgreSQL│ │         │ │ElastiCache│ │          │ │
│  │  │ └──────────┘ │         │ └──────────┘ │           │ │
│  │  └──────────────┘         └──────────────┘           │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Key Talking Points

#### 1. **Infrastructure as Code (Terraform)**
- "We use Terraform to provision all AWS resources"
- "Everything is version-controlled and reproducible"
- "Can destroy and recreate entire infrastructure in 20 minutes"

#### 2. **Container Orchestration (EKS)**
- "Kubernetes manages our containerized applications"
- "Auto-scaling based on load"
- "Self-healing - automatically restarts failed containers"

#### 3. **Secrets Management (Vault)**
- "HashiCorp Vault securely stores all sensitive data"
- "Database passwords never stored in code"
- "Automatic secret injection into pods"

#### 4. **Security (Kyverno)**
- "Policy engine enforces security rules"
- "Only signed images can run"
- "All containers run as non-root"
- "Resource limits prevent resource exhaustion"

#### 5. **CI/CD (Azure DevOps)**
- "Automated build, test, and deployment pipeline"
- "Security scanning at every stage"
- "Image signing with Cosign"
- "Multi-environment deployment (dev/staging/prod)"

#### 6. **Monitoring (CloudWatch)**
- "Real-time metrics and logs"
- "Automated alerts to Slack"
- "Performance dashboards"

### Demo Flow

1. **Show Infrastructure** (5 min)
   - AWS Console: VPC, EKS, RDS
   - Terraform code
   - Architecture diagram

2. **Show Application** (5 min)
   - Access via ALB URL
   - Backend API docs
   - Frontend interface

3. **Show Security** (5 min)
   - Vault UI
   - Kyverno policies
   - Image signatures

4. **Show CI/CD** (5 min)
   - Azure DevOps pipeline
   - Build stages
   - Deployment process

5. **Show Monitoring** (3 min)
   - CloudWatch dashboards
   - Slack notifications
   - Logs

### Questions They Might Ask

**Q: Why Kubernetes instead of just EC2?**
A: Auto-scaling, self-healing, declarative configuration, industry standard

**Q: Why Vault instead of AWS Secrets Manager?**
A: More features, better integration, dynamic secrets, audit trail

**Q: What happens if a node fails?**
A: Kubernetes automatically reschedules pods to healthy nodes

**Q: How do you handle database backups?**
A: RDS automated backups, point-in-time recovery

**Q: What's the monthly cost?**
A: Approximately $150-200 (EKS $72, RDS $30, EC2 $20, other services $50)

---

## 📚 Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Kyverno Documentation](https://kyverno.io/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

---

## 🎯 Summary

**Total Deployment Time:** ~60-90 minutes

**Execution Order:**
1. ✅ Terraform → Infrastructure
2. ✅ Vault Setup → Secrets
3. ✅ Kubernetes Setup → Platform
4. ✅ Application Deploy → Workloads
5. ✅ Monitoring → Observability

**Result:** Production-ready, secure, scalable application infrastructure! 🚀
