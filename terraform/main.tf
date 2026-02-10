# main.tf

module "security" {
  source       = "./modules/security"
  project_name = var.project_name
  db_password  = var.db_password
}

module "logging" {
  source       = "./modules/logging"
  project_name = var.project_name
  kms_key_arn  = module.security.main_kms_arn
}

module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

module "eks" {
  source       = "./modules/eks"
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnets
}

module "alb" {
  source         = "./modules/alb"
  project_name   = var.project_name
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnets
}

module "rds" {
  source         = "./modules/rds"
  project_name   = var.project_name
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.database_subnets
  eks_node_sg_id = module.eks.node_security_group_id
  kms_key_arn    = module.security.rds_kms_arn
  db_password    = module.security.db_password
}

module "redis" {
  source         = "./modules/redis"
  project_name   = var.project_name
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.database_subnets
  eks_node_sg_id = module.eks.node_security_group_id
  kms_key_arn    = module.security.redis_kms_arn
}

module "vault" {
  source              = "./modules/vault"
  project_name        = var.project_name
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.public_subnets
  allowed_cidr_blocks = ["0.0.0.0/0"] # Temporary for setup, will restrict in next step
  public_key_path     = var.ssh_public_key_path
}

module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
}
