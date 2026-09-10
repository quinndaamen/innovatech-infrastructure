resource "aws_security_group" "aurora" {
  name        = "${var.environment}-aurora-sg"
  description = "Security group for Aurora PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL access from ECS private subnets"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_web_subnet_cidrs
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-aurora-sg"
    Environment = var.environment
  }
}

resource "aws_db_subnet_group" "aurora" {
  name       = "${var.environment}-aurora-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.environment}-aurora-subnet-group"
    Environment = var.environment
  }
}


resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${var.environment}-aurora-cluster"

  engine         = "aurora-postgresql"
  database_name  = var.database_name
  master_username = var.master_username
  master_password = var.master_password

  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  port = 5432

  storage_encrypted = true

  backup_retention_period = 1

  skip_final_snapshot = true
  deletion_protection = false

  apply_immediately = true

  tags = {
    Name        = "${var.environment}-aurora-cluster"
    Environment = var.environment
  }
}

resource "aws_rds_cluster_instance" "aurora" {
  identifier         = "${var.environment}-aurora-instance-1"
  cluster_identifier  = aws_rds_cluster.aurora.id
  instance_class     = "db.t3.medium"
  engine              = aws_rds_cluster.aurora.engine
  engine_version      = aws_rds_cluster.aurora.engine_version

  publicly_accessible = false

  apply_immediately = true

  tags = {
    Name        = "${var.environment}-aurora-instance-1"
    Environment = var.environment
  }
}