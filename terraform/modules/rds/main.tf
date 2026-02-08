# modules/rds/main.tf

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-sng"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.project_name}-db-sng"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow EKS nodes to connect to PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "main" {
  identifier             = var.project_name
  engine                 = "postgres"
  engine_version         = "15.15"       # Updated to available version
  instance_class         = "db.t3.micro" # Downgraded for Free Tier
  allocated_storage      = 20
  storage_type           = "gp3"
  db_name                = "appdb"
  username               = "postgres"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az                = false # Free Tier doesn't support Multi-AZ
  storage_encrypted       = true
  kms_key_id              = var.kms_key_arn
  ca_cert_identifier      = "rds-ca-rsa2048-g1"
  backup_retention_period = 1 # Lowered for Free Tier
  skip_final_snapshot     = true

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name = "${var.project_name}-rds"
  }
}
