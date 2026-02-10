# outputs.tf

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "rds_endpoint" {
  value = module.rds.db_endpoint
}

output "redis_endpoint" {
  value = module.redis.redis_endpoint
}

output "vault_public_ip" {
  value = module.vault.vault_public_ip
}

output "backend_ecr_url" {
  value = module.ecr.backend_repo_url
}

output "frontend_ecr_url" {
  value = module.ecr.frontend_repo_url
}

output "vault_kms_key_arn" {
  value = module.vault.vault_kms_key_arn
}

output "vault_dynamodb_table_name" {
  value = module.vault.vault_dynamodb_table_name
}

output "vault_security_group_id" {
  value = module.vault.vault_security_group_id
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "db_password" {
  value     = var.db_password != "" ? var.db_password : module.security.db_password
  sensitive = true
}

output "cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}
