# 🌍 Zero-to-Hero Portability & Setup Guide

This guide provides a step-by-step process to deploy the entire infrastructure from scratch on any machine (Linux, macOS, or WSL2).

## 📋 Prerequisites

### 1. Install Required Tools
Ensure the following tools are installed on your local machine:
- **AWS CLI** (configured with admin access)
- **Terraform** (v1.6.0+)
- **kubectl**
- **Helm**
- **Ansible**
- **jq** (essential for script automation)

### 2. AWS Configuration
Run `aws configure` and set:
- `AWS Access Key ID`
- `AWS Secret Access Key`
- `Default region`: (e.g., `us-east-1` or `us-east-2`)
- `Default output format`: `json`

### 3. SSH Key Pair
Generate an SSH key pair if you don't have one:
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

---

## 🚀 Deployment Steps

### Step 1: Clone the Repository
```bash
git clone <your-repo-url>
cd final-project
```

### Step 2: Provision Infrastructure (Terraform)
Navigate to the terraform directory and apply:
```bash
cd terraform
terraform init
terraform apply -var="ssh_public_key_path=~/.ssh/id_rsa.pub" -auto-approve
cd ..
```
*This will create the VPC, EKS, RDS, Redis, ECR repositories, and the Vault EC2 instance.*

### Step 3: Extract Configuration & Generate Scripts
Run the extraction script to pull data from Terraform outputs:
```bash
chmod +x get-config-values.sh
export SSH_KEY_PATH="~/.ssh/id_rsa"
./get-config-values.sh
```
*This generates `run-vault-setup.sh` and `run-vault-config.sh` with the correct IPs and ARNs.*

### Step 4: Setup & Configure Vault
Run the setup script (takes ~5 mins):
```bash
./run-vault-setup.sh
```
*Wait for it to finish. It will create `vault-init-keys.json`.*

Now, extract the root token and configure Vault:
```bash
ROOT_TOKEN=$(cat vault-init-keys.json | jq -r '.root_token')
./run-vault-config.sh $ROOT_TOKEN
```
*This configures Kubernetes auth, policies, and stores secrets.*

### Step 5: Configure kubectl & Cluster Components
Switch context to the new EKS cluster:
```bash
EKS_CLUSTER_NAME=$(cd terraform && terraform output -raw cluster_name)
aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region <your-region>

# Install Cluster Add-ons
./install-kyverno.sh
./install-vault-injector.sh
```

### Step 6: Deploy Application
Build and push images (now using the ECR repos created by Terraform):
```bash
./build-and-push.sh
./deploy.sh dev
```

---

## 🛠 Troubleshooting for Portability

- **SSH Access**: If `run-vault-setup.sh` fails with an SSH error, ensure your local IP is allowed in the Vault Security Group (Terraform `allowed_cidr_blocks`).
- **Permissions**: Ensure your AWS user has `AdministratorAccess`.
- **Environment Variables**: If scripts fail, source the variables manually from `config-values.txt` (if generated).

## 💡 Pro Tip
Everything is designed to be **idempotent**. You can rerun the scripts or Terraform apply safely if a step fails due to a transient network issue.
