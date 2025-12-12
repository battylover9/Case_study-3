
/*
resource "random_password" "db_password" {
  length  = 32
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.School_network}-db-password"
  description = "Master password for RDS database"

  tags = {
    Name = "${var.School_network}-db-password"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = "dbadmin"
    password = random_password.db_password.result
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = 5432
    dbname   = "appdb"
  })
}

resource "aws_db_parameter_group" "main" {
  name   = "${var.School_network}-postgres-params"
  family = "postgres15" 

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameter {
    name  = "log_statement"
    value = "all" 
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" 
  }

  tags = {
    Name = "${var.School_network}-postgres-params"
  }
}


resource "aws_db_instance" "main" {
  identifier = "${var.School_network}-postgres"

  engine         = "postgres"
  engine_version = "15.4" 
  instance_class = "db.t3.micro"  

  allocated_storage     = 20   
  max_allocated_storage = 100  
  storage_type          = "gp3"  
  storage_encrypted     = true   

  db_name  = "appdb"
  username = "dbadmin"
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false  

  multi_az = true  

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled    = true
  performance_insights_retention_period = 7

  parameter_group_name = aws_db_parameter_group.main.name

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"  
  skip_final_snapshot     = false 
  final_snapshot_identifier = "${var.School_network}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  auto_minor_version_upgrade = true
  apply_immediately          = false

  tags = {
    Name = "${var.School_network}-postgres"
    Requirement = "REQ-NCA-P2-01, REQ-NCA-P2-03"  
  }

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier 
    ]
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name = "${var.School_network}-rds-monitoring-role"

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

  tags = {
    Name = "${var.School_network}-rds-monitoring-role"
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${var.School_network}-db-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300 
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors RDS CPU utilization"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = {
    Name = "${var.School_network}-db-high-cpu-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "database_storage" {
  alarm_name          = "${var.School_network}-db-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2147483648 
  alarm_description   = "This metric monitors RDS free storage space"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = {
    Name = "${var.School_network}-db-low-storage-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "database_connections" {
  alarm_name          = "${var.School_network}-db-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80 
  alarm_description   = "This metric monitors RDS database connections"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = {
    Name = "${var.School_network}-db-high-connections-alarm"
  }
}


output "db_instance_endpoint" {
  description = "Database endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_address" {
  description = "Database hostname"
  value       = aws_db_instance.main.address
}

output "db_instance_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "db_secret_arn" {
  description = "ARN of the secret containing database credentials"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "db_dns_name" {
  description = "Internal DNS name for database"
  value       = "database.${var.private_zone_name}"
}

output "database_connection_info" {
  description = "How to connect to the database"
  value = <<-EOT
  
  🗄️ DATABASE IS READY!
  
  ✅ REQ-NCA-P2-03: Database is PRIVATE (not exposed to internet)
  ✅ REQ-NCA-P2-01: Multi-AZ enabled (automatic failover)
  ✅ REQ-NCA-P2-04: Accessible via DNS name
  
  📊 Connection Details:
  Host: database.${var.private_zone_name}
  Port: 5432
  Database: appdb
  Username: dbadmin
  Password: (stored in AWS Secrets Manager)
  
  🔐 Get credentials:
  aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.db_password.name} --query SecretString --output text | jq .
  
  💡 Connection string for applications:
  postgresql://dbadmin:[PASSWORD]@database.${var.private_zone_name}:5432/appdb
  
  🔒 Security:
  - Encrypted at rest: ✓
  - Private subnet only: ✓
  - Multi-AZ for HA: ✓
  - Enhanced monitoring: ✓
  - Automated backups: ✓ (7 days)
  
  ⚠️  Connect from:
  - ECS containers in app tier
  - Bastion host
  - On-premises via VPN
  
  🚫 CANNOT connect from:
  - Public internet (by design!)
  - Your local laptop directly
  
  💰 Estimated cost: ~$30-40/month for db.t3.micro Multi-AZ
  
  EOT
  sensitive = false
}
*/
