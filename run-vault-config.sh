#!/bin/bash
set -euo pipefail

# Ensure local binaries (like kubectl) are in PATH
export PATH="$PATH:/home/mahmoud/Desktop/final-project"

# Vault configuration script
if [ -z "${1:-}" ]; then
    echo "ERROR: Root token required"
    echo "Usage: ./run-vault-config.sh <ROOT_TOKEN>"
    echo ""
    echo "To get the root token:"
    echo "  cat vault-init-keys.json | jq -r '.root_token'"
    exit 1
fi

export VAULT_TOKEN="$1"
if [ "${USE_LOCAL_VAULT:-false}" = "true" ]; then
    export VAULT_ADDR="http://localhost:8200"
else
    export VAULT_ADDR="http://3.144.35.8:8200"
fi
export AWS_REGION="us-east-2"
export K8S_HOST="https://6651584337A95C97244DA3D3EB99945A.gr7.us-east-2.eks.amazonaws.com"
export K8S_CA_CERT="-----BEGIN CERTIFICATE-----
MIIDBTCCAe2gAwIBAgIIfugoEtBriRUwDQYJKoZIhvcNAQELBQAwFTETMBEGA1UE
AxMKa3ViZXJuZXRlczAeFw0yNjAyMTAxNzE4MDdaFw0zNjAyMDgxNzIzMDdaMBUx
EzARBgNVBAMTCmt1YmVybmV0ZXMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
AoIBAQDDHmlj7lUxxOne4oCQWeFcGe+vMBliTyWGR5ZqXaeHRIq+O6OJ98RC9lqy
G8bBMVSiV3hlKAh221R2Fh5v4VghVjCY61NFDSComckd1e+JqDi0f5j7cnXvd+Ib
kEHdU6g8PLv7Oih3BDv89aE5lkC5+lTx7YZMcc/DtA5652prG+/eMMAEMQGgD028
w1TelrqXZnS4justOytRmlYyzB3dKk8Kh7Vxxz6smxcLoy3Gn6dLrICBASaEIVGh
rMsX9nLkzbJN765JSLVR/uWarub0Yd42u8QIDCArXjLMf3TN6iGJRl1J3azzFJCo
r/2+in9KiaCdSZi4pEmUcDp6FczFAgMBAAGjWTBXMA4GA1UdDwEB/wQEAwICpDAP
BgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBQSKTh4y8GBC9jOqNBXEQ3ne8UNCDAV
BgNVHREEDjAMggprdWJlcm5ldGVzMA0GCSqGSIb3DQEBCwUAA4IBAQAmHdBT3COe
+IiGgPfG9Hm9RETu4Vd2wi0yawatrz4HzBDEXpTXrmtn8U8Pzo7WLwisN7Kc67ka
Pj7l3ISpJjO9E8rizB8bZp7EIgzjeKSI8xOpvfJ9Sd1S1rCYKS2w23yAmoz3TMEI
dpAi79NJiHYKLX1YHW6E+iPZUDX5TtYatflQzq9MDhv6tLQ7ue8W/NGDjyIfQhau
R+YsW42h4wY/B3ZKbCNjpey4j2Sf1WP3dELqmRXb2wHTdpdnIh8BRuET9x2pHGVD
7SjiMrH69pePm56CsRo6kkmq1aYqB9kEHRbKPYTNzft5BZTLi/LcydnGT7wkKQSQ
f9uo4ZzRLj7Z
-----END CERTIFICATE-----"
export K8S_OIDC_ISSUER="https://oidc.eks.us-east-2.amazonaws.com/id/6651584337A95C97244DA3D3EB99945A"
export DB_PASSWORD="mLO%bZc1!hKRF5z!"
export RDS_ENDPOINT="capstone-project.cxwgi4yu0yr5.us-east-2.rds.amazonaws.com:5432"
export REDIS_ENDPOINT="master.capstone-project-redis.fhqkub.use2.cache.amazonaws.com"

# Get service account token for Vault auth
echo "Fetching Kubernetes service account token..."
export TOKEN_REVIEWER_JWT=$(kubectl get secret vault-auth-token -n vault -o jsonpath='{.data.token}' | base64 -d)

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
echo "Vault Address: $VAULT_ADDR"
echo ""
