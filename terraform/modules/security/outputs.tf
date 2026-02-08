# modules/security/outputs.tf

output "main_kms_arn" {
  value = aws_kms_key.main.arn
}

output "rds_kms_arn" {
  value = aws_kms_key.rds.arn
}

output "redis_kms_arn" {
  value = aws_kms_key.redis.arn
}

output "db_password" {
  value     = random_password.master.result
  sensitive = true
}

output "db_password_secret_arn" {
  value = aws_secretsmanager_secret.db_password.arn
}
