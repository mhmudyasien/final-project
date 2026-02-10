#!/bin/bash
set -euo pipefail

export VAULT_KMS_KEY_ID="078eef63-bbf1-4eb7-af70-998f8ff221a8"
export VAULT_DYNAMODB_TABLE="capstone-project-vault-storage"
export VAULT_ADDR="http://3.144.35.8:8200"
export AWS_REGION="us-east-2"

echo "=========================================="
echo "Running Vault Setup on 3.144.35.8"
echo "=========================================="
echo ""
echo "Prerequisites:"
echo "  - SSH access to 3.144.35.8"
echo "  - SSH key: /home/mahmoud/.ssh/id_rsa"
echo "  - User: ec2-user"
echo ""

# Check SSH connectivity
if ! ssh -i "/home/mahmoud/.ssh/id_rsa" -o ConnectTimeout=5 -o StrictHostKeyChecking=no ec2-user@3.144.35.8 "echo 'SSH connection successful'" 2>/dev/null; then
    echo "ERROR: Cannot connect to Vault instance via SSH"
    echo "Please check:"
    echo "  1. Security group allows SSH from your IP"
    echo "  2. SSH key is correct"
    echo "  3. Instance is running"
    exit 1
fi

echo "Running Ansible playbook..."
ansible-playbook -i "3.144.35.8," ansible/vault-setup.yml \
    --user ec2-user \
    --private-key "/home/mahmoud/.ssh/id_rsa" \
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
