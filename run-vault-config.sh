#!/bin/bash
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config-values.txt"
VAULT_INIT_FILE="${SCRIPT_DIR}/vault-init-keys.json"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check dependencies
for cmd in jq kubectl aws terraform ansible-playbook; do
    if ! command -v $cmd &> /dev/null; then
        log_error "$cmd is required but not installed."
        exit 1
    fi
done

# Load Config
if [[ -f "$CONFIG_FILE" ]]; then
    set -a
    source "$CONFIG_FILE"
    set +a
else
    log_error "$CONFIG_FILE not found. Run 'terraform apply' and generate config first."
    exit 1
fi

# Get Root Token
if [[ -f "$VAULT_INIT_FILE" ]]; then
    export VAULT_TOKEN=$(jq -r '.root_token' "$VAULT_INIT_FILE")
else
    log_error "$VAULT_INIT_FILE not found. Run 'run-vault-setup.sh' first."
    exit 1
fi

if [[ -z "$VAULT_TOKEN" || "$VAULT_TOKEN" == "null" ]]; then
    log_error "Could not retrieve root token from $VAULT_INIT_FILE"
    exit 1
fi

# Vault Address
if [ "${USE_LOCAL_VAULT:-false}" = "true" ]; then
    export VAULT_ADDR="http://localhost:8200"
else
    # Ensure VAULT_PUBLIC_IP is set (should be in config-values.txt or fetch from tf)
    if [[ -z "${VAULT_PUBLIC_IP:-}" ]]; then
         cd terraform
         export VAULT_PUBLIC_IP=$(terraform output -raw vault_public_ip)
         cd ..
    fi
    export VAULT_ADDR="http://${VAULT_PUBLIC_IP}:8200"
fi

log_info "Vault Address: $VAULT_ADDR"

# Fetch Dynamic Values
log_info "Fetching Kubernetes configuration..."
cd terraform
export RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
export REDIS_ENDPOINT=$(terraform output -raw redis_endpoint)
export DB_PASSWORD=$(terraform output -raw db_password)
export EKS_CLUSTER_NAME=$(terraform output -raw cluster_name)
cd ..

# K8s API Host
export K8S_HOST=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# K8s CA Cert
export K8S_CA_CERT=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 --decode)

# K8s OIDC Issuer
export K8S_OIDC_ISSUER=$(aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --query "cluster.identity.oidc.issuer" --output text)

# Service Account Token
export TOKEN_REVIEWER_JWT=$(kubectl get secret vault-auth-token -n vault -o jsonpath='{.data.token}' | base64 -d)

log_info "Configuration gathered. Running Ansible..."

# Run Ansible
ansible-playbook ansible/vault-config.yml \
    -e "vault_addr=$VAULT_ADDR" \
    -e "vault_token=$VAULT_TOKEN" \
    -e "k8s_host=$K8S_HOST" \
    -e "k8s_ca_cert='$K8S_CA_CERT'" \
    -e "k8s_issuer=$K8S_OIDC_ISSUER" \
    -e "reviewer_jwt=$TOKEN_REVIEWER_JWT" \
    -e "db_host=$RDS_ENDPOINT" \
    -e "db_password=$DB_PASSWORD" \
    -e "redis_host=$REDIS_ENDPOINT"

log_info "Vault configuration complete!"
