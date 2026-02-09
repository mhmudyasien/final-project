# Cloud-Native Vault Migration & EKS Deployment

This project demonstrates a full migration from static Kubernetes secrets to a dynamic secret management system using **HashiCorp Vault** on AWS EKS.

## 🏗 Architecture Overview

The infrastructure is built on AWS using Terraform and managed by Ansible.

- **Vault Server**: Standalone EC2 instance (`t3.micro`) using **DynamoDB** as the storage backend and **AWS KMS** for Auto-Unseal.
- **EKS Cluster**: Managed Kubernetes cluster (v1.29) with a managed node group.
- **Database**: Amazon RDS (PostgreSQL) for persistent storage.
- **Cache**: Amazon ElastiCache (Redis) for session/caching.
- **Ingress**: AWS Application Load Balancer (ALB) and Service LoadBalancers for public access.
- **Secret Injection**: Vault Agent Injector sidecars in Kubernetes pods to securely deliver credentials.

## 🚀 Step-by-Step Implementation

1.  **Infrastructure Provisioning**: Terraform was used to create the networking (VPC), security groups, database, cache, EKS, and the Vault EC2 instance.
2.  **Vault Setup**:
    - Installed Vault via Ansible.
    - Configured DynamoDB storage and KMS Auto-Unseal.
    - Initialized Vault and captured recovery keys.
3.  **Kubernetes Integration**:
    - Installed Vault Agent Injector via Helm.
    - Configured a `Token Reviewer` ServiceAccount on EKS to allow Vault to verify pod identities.
    - Enabled Kubernetes Auth Backend in Vault.
4.  **Application Migration**:
    - Modified backend manifests to remove static environment variables.
    - Added Vault annotations to inject Database and Redis credentials at runtime.
    - Corrected application startup commands (Flask vs Uvicorn).

## 🛠 Problems Faced & Solutions

| Problem | Root Cause | Solution |
| :--- | :--- | :--- |
| **ISP Hijacking** | ISP (Telecom Egypt) redirected/blocked port 8200 HTTP traffic. | Established an **SSH Tunnel** (`-L 8200:127.0.0.1:8200`) to access Vault securely via localhost. |
| **Vault Auth 403** | Missing permissions for the external Vault server to talk to the EKS API. | Created a dedicated **ServiceAccount with `system:auth-delegator`** role and configured it in Vault. |
| **Network Timeout** | EKS Cluster Security Group was blocking port 443 from the Vault SG. | Added an **Ingress Rule** to the EKS Cluster SG to allow Vault to perform token reviews. |
| **Issuer Mismatch** | JWT validation failed due to OIDC issuer differences. | Configured the explicit **EKS OIDC Provider URL** and enabled `disable_iss_validation=true` in Vault. |
| **Port Duplication** | `DATABASE_URL` had double ports (`5432:5432`) from Terraform outputs. | Corrected the Vault Agent template to remove the redundant hardcoded port. |

## 📟 List of Key Commands Used

```bash
# Terraform
terraform init && terraform apply -auto-approve
terraform refresh && terraform output -raw vault_public_ip

# Vault Access (SSH Tunnel)
ssh -i ~/.ssh/id_rsa -L 8200:127.0.0.1:8200 ec2-user@<VAULT_IP> -N -f

# Vault Configuration (Local CLI)
export VAULT_ADDR="http://127.0.0.1:8200"
vault secrets enable -path=secret kv-v2
vault write auth/kubernetes/config kubernetes_host=<EKS_ENDPOINT> ...

# Kubernetes
./kubectl apply -f k8s/dev/
./kubectl rollout restart deployment backend -n dev
./kubectl logs <pod> -c vault-agent-init

# Deployment Scripts
./build-and-push.sh v1.0.0
./deploy.sh v1.0.0
```

## 🧹 Cleanup
To destroy all resources:
```bash
terraform destroy -auto-approve
```
