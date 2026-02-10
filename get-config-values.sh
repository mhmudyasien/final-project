#!/bin/bash
set -euo pipefail

# Enhanced configuration extraction script with error handling and parameterization

# Configuration
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_rsa}"
EC2_USER="${EC2_USER:-ec2-user}"
TERRAFORM_DIR="${TERRAFORM_DIR:-./terraform}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validation functions
validate_terraform() {
    if [ ! -d "$TERRAFORM_DIR" ]; then
        log_error "Terraform directory not found: $TERRAFORM_DIR"
        exit 1
    fi
    
    if [ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
        log_error "Terraform state not found. Have you run 'terraform apply'?"
        exit 1
    fi
}

validate_ssh_key() {
    if [ ! -f "$SSH_KEY_PATH" ]; then
        log_error "SSH key not found: $SSH_KEY_PATH"
        log_error "Set SSH_KEY_PATH environment variable or place key at default location"
        exit 1
    fi
}

get_terraform_output() {
    local output_name=$1
    local value
    
    cd "$TERRAFORM_DIR"
    value=$(terraform output -raw "$output_name" 2>/dev/null || echo "")
    cd - >/dev/null
    
    if [ -z "$value" ]; then
        log_error "Failed to get Terraform output: $output_name"
        exit 1
    fi
    
    echo "$value"
}

# Main execution
log_info "=========================================="
log_info "Extracting Terraform Configuration"
log_info "=========================================="

# Validate prerequisites
validate_terraform
validate_ssh_key

log_info "Fetching Terraform outputs..."

# Extract Terraform outputs with error handling
VAULT_IP=$(get_terraform_output "vault_public_ip")
VAULT_DYNAMODB=$(get_terraform_output "vault_dynamodb_table_name")
VAULT_KMS_ARN=$(get_terraform_output "vault_kms_key_arn")
VAULT_KMS_ID=$(echo "$VAULT_KMS_ARN" | cut -d/ -f2)

RDS_ENDPOINT=$(get_terraform_output "rds_endpoint")
REDIS_ENDPOINT=$(get_terraform_output "redis_endpoint")
DB_PASSWORD=$(get_terraform_output "db_password")

EKS_CLUSTER_NAME=$(get_terraform_output "cluster_name")
AWS_REGION=$(cd "$TERRAFORM_DIR" && terraform state show module.vault.data.aws_region.current | grep 'name ' | cut -d '"' -f2)

log_info "Fetching EKS cluster details..."
EKS_HOST=$(aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --query "cluster.endpoint" --output text 2>/dev/null || echo "")
EKS_CA=$(aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --query "cluster.certificateAuthority.data" --output text 2>/dev/null | base64 -d || echo "")

if [ -z "$EKS_HOST" ] || [ -z "$EKS_CA" ]; then
    log_error "Failed to fetch EKS cluster details"
    exit 1
fi

log_info "Configuration extracted successfully"
log_info "Vault IP: $VAULT_IP"
log_info "RDS Endpoint: $RDS_ENDPOINT"
log_info "Redis Endpoint: $REDIS_ENDPOINT"
log_info "EKS Cluster: $EKS_CLUSTER_NAME"

# Generate vault setup script
log_info "Generating vault-setup execution script..."

cat <<EOF > run-vault-setup.sh
#!/bin/bash
set -euo pipefail

export VAULT_KMS_KEY_ID="$VAULT_KMS_ID"
export VAULT_DYNAMODB_TABLE="$VAULT_DYNAMODB"
export VAULT_ADDR="http://$VAULT_IP:8200"
export AWS_REGION="$AWS_REGION"

echo "=========================================="
echo "Running Vault Setup on $VAULT_IP"
echo "=========================================="
echo ""
echo "Prerequisites:"
echo "  - SSH access to $VAULT_IP"
echo "  - SSH key: $SSH_KEY_PATH"
echo "  - User: $EC2_USER"
echo ""

# Check SSH connectivity
if ! ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=5 -o StrictHostKeyChecking=no $EC2_USER@$VAULT_IP "echo 'SSH connection successful'" 2>/dev/null; then
    echo "ERROR: Cannot connect to Vault instance via SSH"
    echo "Please check:"
    echo "  1. Security group allows SSH from your IP"
    echo "  2. SSH key is correct"
    echo "  3. Instance is running"
    exit 1
fi

echo "Running Ansible playbook..."
ansible-playbook -i "$VAULT_IP," ansible/vault-setup.yml \\
    --user $EC2_USER \\
    --private-key "$SSH_KEY_PATH" \\
    -e "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"

echo ""
echo "=========================================="
echo "Vault Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Check for vault-init-keys.json in current directory"
echo "  2. Extract the root token from the file"
echo "  3. Run: ./run-vault-config.sh <ROOT_TOKEN>"
echo ""
EOF

chmod +x run-vault-setup.sh

# Generate vault config script
log_info "Generating vault-config execution script..."

cat <<EOF > run-vault-config.sh
#!/bin/bash
set -euo pipefail

# Ensure local binaries (like kubectl) are in PATH
export PATH="\$PATH:$(pwd)"

# Vault configuration script
if [ -z "\${1:-}" ]; then
    echo "ERROR: Root token required"
    echo "Usage: ./run-vault-config.sh <ROOT_TOKEN>"
    echo ""
    echo "To get the root token:"
    echo "  cat vault-init-keys.json | jq -r '.root_token'"
    exit 1
fi

export VAULT_TOKEN="\$1"
if [ "\${USE_LOCAL_VAULT:-false}" = "true" ]; then
    export VAULT_ADDR="http://localhost:8200"
else
    export VAULT_ADDR="http://$VAULT_IP:8200"
fi
export AWS_REGION="$AWS_REGION"
export K8S_HOST="$EKS_HOST"
export K8S_CA_CERT="$EKS_CA"
export K8S_OIDC_ISSUER="$(get_terraform_output "cluster_oidc_issuer_url")"
export DB_PASSWORD="$DB_PASSWORD"
export RDS_ENDPOINT="$RDS_ENDPOINT"
export REDIS_ENDPOINT="$REDIS_ENDPOINT"

# Get service account token for Vault auth
echo "Fetching Kubernetes service account token..."
export TOKEN_REVIEWER_JWT=\$(kubectl get secret vault-auth-token -n vault -o jsonpath='{.data.token}' | base64 -d)

echo "=========================================="
echo "Configuring Vault Secrets & Auth"
echo "=========================================="
echo ""

ansible-playbook ansible/vault-config.yml

echo ""
echo "=========================================="
echo "Vault Configuration Complete!"
echo "=========================================="
echo ""
echo "Your application can now retrieve secrets from Vault"
echo "Vault Address: \$VAULT_ADDR"
echo ""
EOF

chmod +x run-vault-config.sh

log_info "=========================================="
log_info "Scripts Generated Successfully!"
log_info "=========================================="
echo ""
log_info "Generated files:"
log_info "  - run-vault-setup.sh"
log_info "  - run-vault-config.sh"
echo ""
log_info "Execution steps:"
log_info "  1. Run: ./run-vault-setup.sh"
log_info "  2. Extract root token: cat vault-init-keys.json | jq -r '.root_token'"
log_info "  3. Run: ./run-vault-config.sh <ROOT_TOKEN>"
echo ""
log_info "Configuration:"
log_info "  SSH Key: $SSH_KEY_PATH"
log_info "  EC2 User: $EC2_USER"
log_info "  Vault IP: $VAULT_IP"
echo ""
