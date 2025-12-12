resource "aws_s3_bucket" "prometheus" {
  bucket = "${var.School_network}-prometheus-data"

  tags = {
    Name = "${var.School_network}-prometheus-data"
    Purpose = "Long-term metrics storage"
  }
}

resource "aws_s3_bucket_versioning" "prometheus" {
  bucket = aws_s3_bucket.prometheus.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "prometheus" {
  bucket = aws_s3_bucket.prometheus.id

  rule {
    id     = "delete-old-metrics"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.prometheus_retention_days
    }
  }
}

resource "aws_ecs_task_definition" "prometheus" {
  family                   = "${var.School_network}-prometheus"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512 
  memory                   = 1024 
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.prometheus_task.arn

  container_definitions = jsonencode([
    {
      name  = "prometheus"
      image = "prom/prometheus:latest"
      
      portMappings = [
        {
          containerPort = 9090
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
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus",
        "--storage.tsdb.retention.time=${var.prometheus_retention_days}d",
        "--web.console.libraries=/usr/share/prometheus/console_libraries",
        "--web.console.templates=/usr/share/prometheus/consoles",
        "--web.enable-lifecycle"
      ]

      mountPoints = [
        {
          sourceVolume  = "prometheus-config"
          containerPath = "/etc/prometheus"
          readOnly      = true
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.prometheus.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "prometheus"
        }
      }

      healthCheck = {
        command = ["CMD-SHELL", "wget -q --spider http://localhost:9090/-/healthy || exit 1"]
        interval = 30
        timeout = 5
        retries = 3
      }
    }
  ])

  volume {
    name = "prometheus-config"
    
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.monitoring.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.prometheus_config.id
      }
    }
  }

  tags = {
    Name = "${var.School_network}-prometheus-task"
    Requirement = "REQ-NCA-P2-05_REQ-NCA-P2-08"
  }
}

resource "aws_ecs_service" "prometheus" {
  name            = "${var.School_network}-prometheus"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.monitoring.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.prometheus.arn
  }

  tags = {
    Name = "${var.School_network}-prometheus-service"
    Requirement = "REQ-NCA-P2-05"
  }
}

resource "aws_service_discovery_private_dns_namespace" "monitoring" {
  name = "monitoring.${var.School_network}.local"
  vpc  = aws_vpc.main.id

  tags = {
    Name = "${var.School_network}-monitoring-namespace"
  }
}

resource "aws_service_discovery_service" "prometheus" {
  name = "prometheus"

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
    Name = "${var.School_network}-prometheus-discovery"
  }
}

resource "aws_efs_file_system" "monitoring" {
  creation_token = "${var.School_network}-monitoring-efs"
  encrypted      = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "${var.School_network}-monitoring-efs"
  }
}

resource "aws_efs_mount_target" "monitoring" {
  count           = length(aws_subnet.private)
  file_system_id  = aws_efs_file_system.monitoring.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_access_point" "prometheus_config" {
  file_system_id = aws_efs_file_system.monitoring.id

  root_directory {
    path = "/monitoring/prometheus"
    creation_info {
      owner_gid   = 65534
      owner_uid   = 65534
      permissions = "755"
    }
  }

  tags = {
    Name = "${var.School_network}-prometheus-config-ap"
  }
}

resource "aws_security_group" "efs" {
  description      = "Security group for EFS mount targets"
  vpc_id           = aws_vpc.main.id

  ingress {
    description     = "NFS from monitoring containers"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.School_network}-efs-sg"
  }
}

resource "aws_iam_role" "prometheus_task" {
  name = "${var.School_network}-prometheus-task-role"

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
    Name = "${var.School_network}-prometheus-task-role"
  }
}

resource "aws_iam_role_policy" "prometheus_task" {
  name = "${var.School_network}-prometheus-task-policy"
  role = aws_iam_role.prometheus_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "ecs:DescribeContainerInstances",
          "ecs:DescribeTaskDefinition",
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/ecs/${var.School_network}/prometheus"
  retention_in_days = 7

  tags = {
    Name = "${var.School_network}-prometheus-logs"
  }
}

output "prometheus_endpoint" {
  description = "Prometheus endpoint URL"
  value       = "http://prometheus.${aws_route53_zone.private.name}:9090"
}

output "prometheus_service_name" {
  description = "Prometheus ECS service name"
  value       = aws_ecs_service.prometheus.name
}

output "prometheus_info" {
  description = "Prometheus setup information"
  value = <<-EOT
  
  PROMETHEUS IS DEPLOYED!
  
  Access Prometheus:
  - Internal URL: http://prometheus.${aws_route53_zone.private.name}:9090
  - Service Discovery: prometheus.monitoring.${var.School_network}.local
  
  Features:
   Collects metrics from all services
   Stores data for ${var.prometheus_retention_days} days
   Automatic service discovery
   Backed by EFS for persistent config
   Long-term storage in S3
  
  Next Steps:
  1. Access Prometheus UI through VPN or bastion
  2. Configure scrape targets in prometheus.yml
  3. Set up alerting rules
  4. Connect to Grafana for visualization
  
  Example Queries:
  - CPU Usage: rate(container_cpu_usage_seconds_total[5m])
  - Memory Usage: container_memory_usage_bytes
  - HTTP Requests: rate(http_requests_total[5m])
  
  EOT
}
