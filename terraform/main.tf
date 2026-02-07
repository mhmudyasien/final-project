# ============ VPC ============
module "vpc" {
  source     = "./modules/vpc"
  name       = "devsecops-vpc"
  cidr_block = "10.0.0.0/16"
}

# ============ Internet Gateway ============
resource "aws_internet_gateway" "igw" {
  vpc_id = module.vpc.vpc_id
  tags   = { Name = "devsecops-igw" }
}

# ============ Public Subnets (Frontend) ============
module "public_subnet_1" {
  source            = "./modules/subnet"
  vpc_id            = module.vpc.vpc_id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-2a"
  map_public_ip     = true
  name              = "public-subnet-1"
}

module "public_subnet_2" {
  source            = "./modules/subnet"
  vpc_id            = module.vpc.vpc_id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-2b"
  map_public_ip     = true
  name              = "public-subnet-2"
}

# ============ Private Subnets (Backend) ============
module "private_backend_subnet_1" {
  source            = "./modules/subnet"
  vpc_id            = module.vpc.vpc_id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  map_public_ip     = false
  name              = "private-backend-subnet-1"
}

module "private_backend_subnet_2" {
  source            = "./modules/subnet"
  vpc_id            = module.vpc.vpc_id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-2b"
  map_public_ip     = false
  name              = "private-backend-subnet-2"
}

# ============ Private Subnets (Database) ============
module "private_db_subnet_1" {
  source            = "./modules/subnet"
  vpc_id            = module.vpc.vpc_id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1a"
  map_public_ip     = false
  name              = "private-db-subnet-1"
}

module "private_db_subnet_2" {
  source            = "./modules/subnet"
  vpc_id            = module.vpc.vpc_id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "us-east-2b"
  map_public_ip     = false
  name              = "private-db-subnet-2"
}

# ============ NAT Gateways ============
module "nat_gw_1" {
  source           = "./modules/nat_gateway"
  public_subnet_id = module.public_subnet_1.subnet_id
  name             = "nat-gateway-1"
}

module "nat_gw_2" {
  source           = "./modules/nat_gateway"
  public_subnet_id = module.public_subnet_2.subnet_id
  name             = "nat-gateway-2"
}

# ============ Route Tables ============

# Public route table
module "public_rt_1" {
  source                = "./modules/route_table"
  vpc_id                = module.vpc.vpc_id
  subnet_id             = module.public_subnet_1.subnet_id
  igw_id                = aws_internet_gateway.igw.id
  create_internet_route = true
  name                  = "public-rt-1"
}

module "public_rt_2" {
  source                = "./modules/route_table"
  vpc_id                = module.vpc.vpc_id
  subnet_id             = module.public_subnet_2.subnet_id
  igw_id                = aws_internet_gateway.igw.id
  create_internet_route = true
  name                  = "public-rt-2"
}

# Private backend route tables
module "private_backend_rt_1" {
  source                = "./modules/route_table"
  vpc_id                = module.vpc.vpc_id
  subnet_id             = module.private_backend_subnet_1.subnet_id
  igw_id                = null
  create_internet_route = false
  name                  = "private-backend-rt-1"
}

module "private_backend_rt_2" {
  source                = "./modules/route_table"
  vpc_id                = module.vpc.vpc_id
  subnet_id             = module.private_backend_subnet_2.subnet_id
  igw_id                = null
  create_internet_route = false
  name                  = "private-backend-rt-2"
}

# Private DB route tables
module "private_db_rt_1" {
  source                = "./modules/route_table"
  vpc_id                = module.vpc.vpc_id
  subnet_id             = module.private_db_subnet_1.subnet_id
  igw_id                = null
  create_internet_route = false
  name                  = "private-db-rt-1"
}

module "private_db_rt_2" {
  source                = "./modules/route_table"
  vpc_id                = module.vpc.vpc_id
  subnet_id             = module.private_db_subnet_2.subnet_id
  igw_id                = null
  create_internet_route = false
  name                  = "private-db-rt-2"
}

# Add NAT gateway routes to private subnets
resource "aws_route" "private_backend_1_nat" {
  route_table_id         = module.private_backend_rt_1.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = module.nat_gw_1.nat_gateway_id
}

resource "aws_route" "private_backend_2_nat" {
  route_table_id         = module.private_backend_rt_2.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = module.nat_gw_2.nat_gateway_id
}

resource "aws_route" "private_db_1_nat" {
  route_table_id         = module.private_db_rt_1.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = module.nat_gw_1.nat_gateway_id
}

resource "aws_route" "private_db_2_nat" {
  route_table_id         = module.private_db_rt_2.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = module.nat_gw_2.nat_gateway_id
}
