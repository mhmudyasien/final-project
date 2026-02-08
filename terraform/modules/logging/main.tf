# modules/logging/main.tf

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.project_name}/cluster"
  retention_in_days = var.retention_days
  kms_key_id        = var.kms_key_arn # Encrypted logs

  tags = {
    Name = "${var.project_name}-eks-logs"
  }
}

resource "aws_cloudwatch_log_group" "app_backend" {
  name              = "/aws/app/${var.project_name}/backend"
  retention_in_days = var.retention_days
  kms_key_id        = var.kms_key_arn

  tags = {
    Name = "${var.project_name}-backend-logs"
  }
}

resource "aws_cloudwatch_log_group" "app_frontend" {
  name              = "/aws/app/${var.project_name}/frontend"
  retention_in_days = var.retention_days
  kms_key_id        = var.kms_key_arn

  tags = {
    Name = "${var.project_name}-frontend-logs"
  }
}
