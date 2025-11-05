# Aurora PostgreSQL Cluster with pgvector support

# DB Subnet Group
resource "aws_db_subnet_group" "aurora_subnet_group" {
  name       = "${var.cluster_name}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.cluster_name}-subnet-group"
  }
}

# Security Group for Aurora
resource "aws_security_group" "aurora_sg" {
  name        = "${var.cluster_name}-sg"
  description = "Security group for Aurora PostgreSQL cluster"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-sg"
  }
}

# Aurora Cluster Parameter Group (PostgreSQL 15 with pgvector)
resource "aws_rds_cluster_parameter_group" "aurora_cluster_pg" {
  name        = "${var.cluster_name}-cluster-pg"
  family      = "aurora-postgresql15"
  description = "Aurora PostgreSQL 15 cluster parameter group with pgvector"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements,pgvector"
  }

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = {
    Name = "${var.cluster_name}-cluster-pg"
  }
}

# Aurora DB Parameter Group
resource "aws_db_parameter_group" "aurora_db_pg" {
  name        = "${var.cluster_name}-db-pg"
  family      = "aurora-postgresql15"
  description = "Aurora PostgreSQL 15 DB parameter group"

  tags = {
    Name = "${var.cluster_name}-db-pg"
  }
}

# Aurora PostgreSQL Cluster
resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier              = var.cluster_name
  engine                          = "aurora-postgresql"
  engine_version                  = "15.4"
  database_name                   = var.database_name
  master_username                 = var.master_username
  master_password                 = var.master_password
  db_subnet_group_name            = aws_db_subnet_group.aurora_subnet_group.name
  vpc_security_group_ids          = [aws_security_group.aurora_sg.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_cluster_pg.name

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "mon:04:00-mon:05:00"

  enabled_cloudwatch_logs_exports = ["postgresql"]
  storage_encrypted               = true
  skip_final_snapshot             = var.skip_final_snapshot
  final_snapshot_identifier       = var.skip_final_snapshot ? null : "${var.cluster_name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  apply_immediately = true

  tags = {
    Name = var.cluster_name
  }
}

# Aurora Cluster Instances
resource "aws_rds_cluster_instance" "aurora_instance" {
  count              = var.instance_count
  identifier         = "${var.cluster_name}-instance-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.aurora_cluster.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.aurora_cluster.engine
  engine_version     = aws_rds_cluster.aurora_cluster.engine_version

  db_parameter_group_name = aws_db_parameter_group.aurora_db_pg.name
  publicly_accessible     = false

  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring_role.arn

  tags = {
    Name = "${var.cluster_name}-instance-${count.index + 1}"
  }
}

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring_role" {
  name = "${var.cluster_name}-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring_policy" {
  role       = aws_iam_role.rds_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}