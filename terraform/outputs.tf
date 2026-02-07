output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = [
    module.public_subnet_1.subnet_id,
    module.public_subnet_2.subnet_id
  ]
}

output "private_backend_subnets" {
  value = [
    module.private_backend_subnet_1.subnet_id,
    module.private_backend_subnet_2.subnet_id
  ]
}

output "private_db_subnets" {
  value = [
    module.private_db_subnet_1.subnet_id,
    module.private_db_subnet_2.subnet_id
  ]
}
