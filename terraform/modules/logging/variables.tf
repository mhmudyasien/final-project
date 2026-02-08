# modules/logging/variables.tf

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "kms_key_arn" {
  description = "KMS Key ARN for encryption at rest"
  type        = string
}
