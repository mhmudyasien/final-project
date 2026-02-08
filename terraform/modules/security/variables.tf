# modules/security/variables.tf

variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "db_password" {
  description = "Optional DB password, if empty a random one will be generated"
  type        = string
  default     = ""
  sensitive   = true
}
