#!/bin/bash
export VAULT_KMS_KEY_ID="350bade4-f93b-4a21-818e-f2137accd9a2"
export VAULT_DYNAMODB_TABLE="capstone-project-vault-storage"
export VAULT_ADDR="http://3.128.206.255:8200"
# For setup, we target the EC2 instance. 
# Assuming SSH access via bastion or direct if allowed. 
# Since we are in a pipeline/local env, we'll use the inventory file or -i IP,
echo "Running Vault Setup..."
ansible-playbook -i "3.128.206.255," ansible/vault-setup.yml --user ec2-user --private-key ~/.ssh/id_rsa 

echo "Check for vault-init-keys.json for Root Token!"
