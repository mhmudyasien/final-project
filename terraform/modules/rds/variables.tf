# modules/rds/variables.tf

variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "eks_node_sg_id" {
  description = "Security group of EKS nodes for ingress"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS ARN for storage encryption"
  type        = string
}

variable "db_password" {
  type      = string
  sensitive = true
}
