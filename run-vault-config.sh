#!/bin/bash
# User must provide Root Token
if [ -z "$1" ]; then echo "Usage: ./run-vault-config.sh <ROOT_TOKEN>"; exit 1; fi

export VAULT_TOKEN="$1"
export VAULT_ADDR="http://127.0.0.1:8200"
export K8S_HOST="https://E9A24F205507056D535A3A9656DB7800.gr7.us-east-2.eks.amazonaws.com"
export K8S_CA_CERT="-----BEGIN CERTIFICATE-----
MIIDBTCCAe2gAwIBAgIIelzrPbn/rTgwDQYJKoZIhvcNAQELBQAwFTETMBEGA1UE
AxMKa3ViZXJuZXRlczAeFw0yNjAyMDkxMjA3MzhaFw0zNjAyMDcxMjEyMzhaMBUx
EzARBgNVBAMTCmt1YmVybmV0ZXMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
AoIBAQDMr2PeEWhWGX9zPwc8WIB3XL8r4ZrPY6WZCpzX7ANZr7Yf5ducFsMrmV1D
/NphJACmRXMz5VYVEFpCLFYeYuAkolIegivDmEkzUdsNWnMAUL6bdk7tfNx2Oo/t
fV0Jt9cEIVb6bxPTaTcnS/RcmySQs+1sIUI6lMgHX/z/lFo+hv3NWKD9s6ps2gb0
61eV/G9cDp0asl2VL7tmhX3R/VqS8sLoV543I6YxdlDp+yhtS9YQsczbVMiAAdYB
59JSLlDlgjPB/wXCXuCFkd/bsojVQFNBZbLNPiw8sYkT/vbN6foqvxOrozuHSEau
moEytf9tpkQ00uJPy9BxI4RSNiqRAgMBAAGjWTBXMA4GA1UdDwEB/wQEAwICpDAP
BgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBS1dRdIRdcTJmTFqzf/g3jF9e0wiTAV
BgNVHREEDjAMggprdWJlcm5ldGVzMA0GCSqGSIb3DQEBCwUAA4IBAQC1DFy/Ab4E
yPMPQkUv6SIRddX5I6pyyTMguPNRQKpf/8EfhKdCqE3NCkrd+T22FdhBOPG0d0Vw
bVOIZRXX/KuswJVbgopsYc7zU/HUZB05f7vC9PomIGVtStD0u1FndMiB1NBH2Lvb
eIBcRPJBZgsUAGhli2KyV00jjJxu2+7zl2TTugrHRReci7G4GAcWTeysVWs9aW9f
21B48JClcb91lu5dEX7ZCNJtQUlDXCROlfIFQs6oy/Nai4IdVgWgUi+HXPpf2mRZ
1Mz4bUz8r3tzcV2v2Y0Mc+pZzeAZ0MYkCLScxdxvj2q/7KAq7KjXEboWiEuWvpWn
DkQx4yd4uxLL
-----END CERTIFICATE-----"
export DB_PASSWORD="NV5>Eq78NJn5-ac("
export RDS_ENDPOINT="capstone-project.cxwgi4yu0yr5.us-east-2.rds.amazonaws.com:5432"
export REDIS_ENDPOINT="master.capstone-project-redis.fhqkub.use2.cache.amazonaws.com"

echo "Configuring Vault Secrets & Auth..."
ansible-playbook ansible/vault-config.yml
