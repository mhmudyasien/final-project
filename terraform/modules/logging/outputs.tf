# modules/logging/outputs.tf

output "eks_log_group_name" {
  value = aws_cloudwatch_log_group.eks.name
}
