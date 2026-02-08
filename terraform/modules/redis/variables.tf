# modules/redis/variables.tf

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
  type = string
}

variable "kms_key_arn" {
  type = string
}
