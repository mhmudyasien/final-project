#!/bin/bash
set -e

# Configuration
EKS_CLUSTER_NAME=$(cd terraform && terraform output -raw cluster_name)
AWS_REGION=$(aws configure get region)

echo "Updating kubeconfig for cluster: $EKS_CLUSTER_NAME"
aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_REGION

echo "Adding HashiCorp Helm repository..."
./helm repo add hashicorp https://helm.releases.hashicorp.com
./helm repo update

echo "Installing Vault Agent Injector..."
# We only install the injector, not the full Vault server on K8s
# since we are using an external Vault on EC2.
./helm upgrade --install vault hashicorp/vault \
  --set "injector.externalVaultAddr=http://$(cd terraform && terraform output -raw vault_public_ip):8200" \
  --namespace vault --create-namespace

echo "Vault Agent Injector installed."
