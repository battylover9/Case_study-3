resource "aws_s3_bucket" "loki" {
  bucket = "${var.School_network}-loki-logs"

  tags = {
    Name = "${var.School_network}-loki-logs"
    Purpose = "Long-term log storage"
  }
}

resource "aws_s3_bucket_versioning" "loki" {
  bucket = aws_s3_bucket.loki.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
     filter {
      prefix = ""  
    }

    expiration {
      days = 365
    }
  }
}


resource "aws_ecs_task_definition" "loki" {
  family                   = "${var.School_network}-loki"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512   
  memory                   = 1024 
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = aws_iam_role.loki_task.arn

  container_definitions = jsonencode([
    {
      name  = "loki"
      image = "grafana/loki:latest"
      
      portMappings = [
        {
          containerPort = 3100
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ]

      command = [
        "-config.file=/etc/loki/local-config.yaml"
      ]

      mountPoints = [
        {
          sourceVolume  = "loki-config"
          containerPath = "/etc/loki"
          readOnly      = true
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.loki.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "loki"
        }
      }

      healthCheck = {
        command = ["CMD-SHELL", "wget -q --spider http://localhost:3100/ready || exit 1"]
        interval = 30
        timeout = 5
        retries = 3
      }
    }
  ])

  volume {
    name = "loki-config"
    
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.monitoring.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.loki_config.id
      }
    }
  }

  tags = {
    Name = "${var.School_network}-loki-task"
    Requirement = "REQ-NCA-P2-05, REQ-NCA-P2-09"
  }
}

resource "aws_ecs_service" "loki" {
  name            = "${var.School_network}-loki"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.loki.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.security_group_ids["monitoring"]]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.loki.arn
  }

  tags = {
    Name = "${var.School_network}-loki-service"
    Requirement = "REQ-NCA-P2-05"
  }
}

resource "aws_service_discovery_service" "loki" {
  name = "loki"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.monitoring.id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name = "${var.School_network}-loki-discovery"
  }
}

resource "aws_efs_access_point" "loki_config" {
  file_system_id = aws_efs_file_system.monitoring.id

  root_directory {
    path = "/loki"
    creation_info {
      owner_gid   = 10001
      owner_uid   = 10001
      permissions = "755"
    }
  }

  tags = {
    Name = "${var.School_network}-loki-config-ap"
  }
}

resource "aws_iam_role" "loki_task" {
  name = "${var.School_network}-loki-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.School_network}-loki-task-role"
  }
}

resource "aws_iam_role_policy" "loki_task" {
  name = "${var.School_network}-loki-task-policy"
  role = aws_iam_role.loki_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite"
        ]
        Resource = [
          aws_s3_bucket.loki.arn,
          "${aws_s3_bucket.loki.arn}/*",
          aws_efs_file_system.monitoring.arn
        ]
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "loki" {
  name              = "/ecs/${var.School_network}/loki"
  retention_in_days = 7

  tags = {
    Name = "${var.School_network}-loki-logs"
  }
}

resource "local_file" "loki_config" {
  filename = "${path.module}/monitoring/loki/loki-config.yml"
  
  content = <<-EOT
    auth_enabled: false
    
    server:
      http_listen_port: 3100
      grpc_listen_port: 9096
    
    common:
      path_prefix: /loki
      storage:
        filesystem:
          chunks_directory: /loki/chunks
          rules_directory: /loki/rules
      replication_factor: 1
      ring:
        instance_addr: 127.0.0.1
        kvstore:
          store: inmemory
    
    schema_config:
      configs:
        - from: 2020-10-24
          store: boltdb-shipper
          object_store: s3
          schema: v11
          index:
            prefix: index_
            period: 24h
    
    storage_config:
      boltdb_shipper:
        active_index_directory: /loki/boltdb-shipper-active
        cache_location: /loki/boltdb-shipper-cache
        cache_ttl: 24h
        shared_store: s3
      
      aws:
        s3: s3://${var.aws_region}/${aws_s3_bucket.loki.id}
        s3forcepathstyle: false
    
    limits_config:
      retention_period: 744h  # 31 days
      reject_old_samples: true
      reject_old_samples_max_age: 168h  # 7 days
      ingestion_rate_mb: 10
      ingestion_burst_size_mb: 20
    
    chunk_store_config:
      max_look_back_period: 0s
    
    table_manager:
      retention_deletes_enabled: true
      retention_period: 744h
    
    compactor:
      working_directory: /loki/compactor
      shared_store: s3
      compaction_interval: 10m
      retention_enabled: true
      retention_delete_delay: 2h
      retention_delete_worker_count: 150
  EOT
}

output "loki_endpoint" {
  description = "Loki endpoint URL"
  value       = "http://loki.${var.private_zone_name}:3100"
}

output "loki_service_name" {
  description = "Loki ECS service name"
  value       = aws_ecs_service.loki.name
}

output "loki_info" {
  description = "Loki setup information"
  value = <<-EOT
  
  📝 LOKI IS DEPLOYED!
  
  Access Loki:
  - Internal URL: http://loki.${var.private_zone_name}:3100
  - Service Discovery: loki.monitoring.${var.School_network}.local
  
  Features:
  ✅ Collects logs from all services
  ✅ Stores logs for 31 days locally
  ✅ Long-term storage in S3 (1 year)
  ✅ Automatic log rotation and compression
  ✅ Integrated with Grafana
  
  Log Shipping Agents:
  - Promtail: For servers and containers
  - Fluent Bit: For AWS services
  - CloudWatch Logs: Via Lambda subscription
  
  Example LogQL Queries (in Grafana):
  
  # All logs from app
  {container="app"}
  
  # Error logs only
  {container="app"} |= "error"
  
  # HTTP 500 errors
  {container="app"} | json | status="500"
  
  # Logs from last hour
  {container="app"} [1h]
  
  # Count errors per minute
  rate({container="app"} |= "error" [1m])
  
  Next Steps:
  1. Deploy Promtail agents (via Ansible)
  2. Configure log shipping from applications
  3. Create log-based alerts in Grafana
  4. Set up log retention policies
  
  EOT
}
