#!/bin/bash
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config-values.txt"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check dependencies
for cmd in jq aws terraform ansible-playbook; do
    if ! command -v $cmd &> /dev/null; then
        log_error "$cmd is required but not installed."
        exit 1
    fi
done

# Load Config or Fetch from Terraform
if [[ -f "$CONFIG_FILE" ]]; then
    set -a
    source "$CONFIG_FILE"
    set +a
fi

if [[ -z "${VAULT_PUBLIC_IP:-}" ]]; then
    log_info "Fetching Vault Public IP from Terraform..."
    cd terraform
    export VAULT_PUBLIC_IP=$(terraform output -raw vault_public_ip)
    export AWS_REGION=$(aws configure get region)
    cd ..
fi

if [[ -z "${VAULT_PUBLIC_IP:-}" ]]; then
    log_error "Could not determine Vault Public IP. Run terraform apply first."
    exit 1
fi

log_info "Vault IP: $VAULT_PUBLIC_IP"
log_info "Region: ${AWS_REGION:-us-east-2}"

# Create temporary inventory
cat > ansible/inventory.ini <<EOF
[vault]
$VAULT_PUBLIC_IP ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

log_info "Running Ansible Setup..."

# Run Ansible
export ANSIBLE_CONFIG=ansible/ansible.cfg
ansible-playbook -i ansible/inventory.ini ansible/vault-setup.yml \
    -e "aws_region=${AWS_REGION:-us-east-2}"

log_info "Vault setup complete! Keys saved to vault-init-keys.json"
