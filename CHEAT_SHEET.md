# 🎯 Quick Start Cheat Sheet

**Fast reference for deploying the infrastructure**

---

## ⚡ TL;DR - Complete Deployment

```bash
# 1. INFRASTRUCTURE (20-30 min)
cd terraform/
terraform init
terraform apply -auto-approve
cd ..

# Save outputs
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
export VAULT_PUBLIC_IP=$(terraform output -raw vault_public_ip)

# 2. VAULT SETUP (10-15 min)
chmod +x run-vault-setup.sh run-vault-config.sh
./run-vault-setup.sh      # Initialize Vault
./run-vault-config.sh     # Configure Kubernetes auth

# 3. KUBERNETES SETUP (15-20 min)
aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region us-east-2

chmod +x install-*.sh
./install-alb-controller.sh   # Install ALB Controller
./install-kyverno.sh          # Install Kyverno policies
./install-vault-injector.sh   # Install Vault injector

kubectl apply -f k8s/dev/namespace.yaml
kubectl apply -f k8s/staging/namespace.yaml
kubectl apply -f k8s/prod/namespace.yaml

# 4. APPLICATION DEPLOYMENT (10-15 min)
chmod +x build-and-push.sh deploy.sh
./build-and-push.sh       # Build & push Docker images
./deploy.sh dev           # Deploy to dev environment

# 5. GET APPLICATION URL
kubectl get ingress -n dev
```

**Total Time: ~60-90 minutes**

---

## 📋 Script Execution Order

| # | Script | Purpose | Time | Dependencies |
|---|--------|---------|------|--------------|
| 1 | `terraform apply` | Create infrastructure | 20-30 min | AWS credentials |
| 2 | `run-vault-setup.sh` | Initialize Vault | 5 min | Terraform complete |
| 3 | `run-vault-config.sh` | Configure Vault | 5 min | Vault initialized |
| 4 | `install-alb-controller.sh` | Install ALB | 5 min | EKS ready |
| 5 | `install-kyverno.sh` | Install policies | 3 min | EKS ready |
| 6 | `install-vault-injector.sh` | Install injector | 2 min | Vault configured |
| 7 | `build-and-push.sh` | Build images | 10 min | ECR created |
| 8 | `deploy.sh dev` | Deploy app | 5 min | Images pushed |

---

## 🔍 What Each Script Does

### Infrastructure Scripts

**`terraform apply`**
- Creates VPC, subnets, NAT gateways
- Provisions EKS cluster with 2 nodes
- Creates RDS PostgreSQL database
- Creates ElastiCache Redis cluster
- Launches Vault EC2 instance

### Vault Scripts

**`run-vault-setup.sh`**
- SSHs to Vault EC2
- Initializes Vault (creates 5 unseal keys)
- Unseals Vault (uses 3 keys)
- Enables secrets engine
- Saves keys to `vault-init-keys.json`

**`run-vault-config.sh`**
- Enables Kubernetes auth
- Creates policies for webapp
- Creates Kubernetes role
- Stores DB credentials in Vault
- Saves token to `vault_auth_token.txt`

### Kubernetes Scripts

**`install-alb-controller.sh`**
- Creates IAM policy for ALB
- Creates service account
- Installs AWS Load Balancer Controller
- Enables automatic ALB provisioning

**`install-kyverno.sh`**
- Installs Kyverno policy engine
- Applies security policies:
  - Image signature verification
  - Non-root containers
  - Resource limits

**`install-vault-injector.sh`**
- Installs Vault Agent Injector
- Configures Vault connection
- Enables automatic secret injection

### Application Scripts

**`build-and-push.sh`**
- Logs into AWS ECR
- Builds backend Docker image
- Builds frontend Docker image
- Tags and pushes to ECR

**`deploy.sh [env]`**
- Substitutes environment variables
- Deploys backend deployment & service
- Deploys frontend deployment & service
- Creates Ingress (ALB)
- Waits for pods to be ready

---

## ✅ Verification Commands

```bash
# Check infrastructure
terraform show
aws eks describe-cluster --name $EKS_CLUSTER_NAME

# Check Vault
ssh ubuntu@$VAULT_PUBLIC_IP "vault status"

# Check Kubernetes
kubectl get nodes
kubectl get pods -A
kubectl get ingress -A

# Check application
ALB_URL=$(kubectl get ingress -n dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$ALB_URL/api/health
```

---

## 🎓 Explaining to Friends

### 1-Minute Pitch
*"I built a production-grade cloud infrastructure on AWS that automatically deploys containerized applications with enterprise security. It uses Kubernetes for orchestration, Vault for secrets, and has automated CI/CD pipelines with security scanning at every stage."*

### 5-Minute Demo
1. **Show AWS Console** - VPC, EKS, RDS
2. **Show Application** - Access via browser
3. **Show Security** - Kyverno policies, Vault
4. **Show Pipeline** - Azure DevOps
5. **Show Monitoring** - CloudWatch dashboards

### Key Buzzwords
- ✅ Infrastructure as Code (Terraform)
- ✅ Container Orchestration (Kubernetes/EKS)
- ✅ Secrets Management (HashiCorp Vault)
- ✅ Policy Enforcement (Kyverno)
- ✅ CI/CD Pipeline (Azure DevOps)
- ✅ Security Scanning (Trivy, SonarQube)
- ✅ Image Signing (Cosign)
- ✅ Monitoring (CloudWatch)

---

## 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| Terraform fails | Check AWS credentials, region |
| Vault sealed | Run unseal commands |
| Pods not starting | Check logs: `kubectl logs <pod>` |
| Image pull error | Verify ECR login |
| ALB not created | Check ALB controller logs |
| Kyverno blocks pod | Check policy reports |

---

## 📊 Architecture Overview

```
Internet → ALB → EKS Pods → RDS/Redis
                    ↓
                  Vault (secrets)
                    ↓
                 Kyverno (policies)
```

---

## 💰 Cost Estimate

| Service | Monthly Cost |
|---------|--------------|
| EKS Cluster | $72 |
| EC2 Nodes (2x t3.small) | $30 |
| RDS PostgreSQL | $30 |
| ElastiCache Redis | $15 |
| Vault EC2 | $10 |
| NAT Gateway | $32 |
| ALB | $20 |
| **Total** | **~$209/month** |

---

## 🚀 Next Steps After Deployment

1. ✅ Set up CloudWatch alarms
2. ✅ Configure Slack notifications
3. ✅ Enable Kyverno enforce mode
4. ✅ Set up automated backups
5. ✅ Configure auto-scaling
6. ✅ Add SSL certificates
7. ✅ Enable WAF

---

For detailed instructions, see [INFRASTRUCTURE_DEPLOYMENT_GUIDE.md](INFRASTRUCTURE_DEPLOYMENT_GUIDE.md)
