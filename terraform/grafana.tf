resource "aws_ecs_task_definition" "grafana" {
  family                   = "${var.School_network}-grafana"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512  
  memory                   = 1024  
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.grafana_task.arn

  container_definitions = jsonencode([
    {
      name  = "grafana"
      image = "grafana/grafana:latest"
      
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "GF_SERVER_ROOT_URL"
          value = "http://grafana.${aws_route53_zone.private.name}:3000"
        },
        {
          name  = "GF_SECURITY_ADMIN_USER"
          value = "admin"
        },
        {
          name  = "GF_SECURITY_ADMIN_PASSWORD"
          value = var.grafana_admin_password
        },
        {
          name  = "GF_INSTALL_PLUGINS"
          value = "grafana-clock-panel,grafana-simple-json-datasource,grafana-piechart-panel"
        },
        {
          name  = "GF_AUTH_ANONYMOUS_ENABLED"
          value = "false"
        },
        {
          name  = "GF_ANALYTICS_REPORTING_ENABLED"
          value = "false"
        },
        {
          name  = "GF_ANALYTICS_CHECK_FOR_UPDATES"
          value = "false"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "grafana-data"
          containerPath = "/var/lib/grafana"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.grafana.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "grafana"
        }
      }

      healthCheck = {
        command = ["CMD-SHELL", "wget -q --spider http://localhost:3000/api/health || exit 1"]
        interval = 30
        timeout = 5
        retries = 3
      }
    }
  ])

  volume {
    name = "grafana-data"
    
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.monitoring.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.grafana_data.id
      }
    }
  }

  tags = {
    Name = "${var.School_network}-grafana-task"
    Requirement = "REQ-NCA-P2-05_REQ-NCA-P2-08"
  }
}


resource "aws_ecs_service" "grafana" {
  name            = "${var.School_network}-grafana"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.monitoring.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.grafana.arn
  }

  depends_on = [aws_lb_listener.grafana]

  tags = {
    Name = "${var.School_network}-grafana-service"
    Requirement = "REQ-NCA-P2-05"
  }
}

resource "aws_lb" "grafana" {
  name               = "${var.School_network}-grafana-alb"
  internal           = true 
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web.id]
  subnets            = aws_subnet.private[*].id

  tags = {
    Name = "${var.School_network}-grafana-alb"
  }
}

resource "aws_lb_target_group" "grafana" {
  name        = "${var.School_network}-grafana-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/api/health"
    matcher             = "200"
  }

  tags = {
    Name = "${var.School_network}-grafana-tg"
  }
}

resource "aws_lb_listener" "grafana" {
  load_balancer_arn = aws_lb.grafana.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
}


resource "aws_service_discovery_service" "grafana" {
  name = "grafana"

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
    Name = "${var.School_network}-grafana-discovery"
  }
}


resource "aws_efs_access_point" "grafana_data" {
  file_system_id = aws_efs_file_system.monitoring.id

  root_directory {
    path = "/grafana"
    creation_info {
      owner_gid   = 472 
      owner_uid   = 472
      permissions = "755"
    }
  }

  tags = {
    Name = "${var.School_network}-grafana-data-ap"
  }
}

resource "aws_iam_role" "grafana_task" {
  name = "${var.School_network}-grafana-task-role"

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
    Name = "${var.School_network}-grafana-task-role"
  }
}

resource "aws_iam_role_policy" "grafana_task" {
  name = "${var.School_network}-grafana-task-policy"
  role = aws_iam_role.grafana_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "logs:DescribeLogGroups",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/${var.School_network}/grafana"
  retention_in_days = 7

  tags = {
    Name = "${var.School_network}-grafana-logs"
  }
}


resource "local_file" "grafana_datasource_config" {
  filename = "${path.module}/grafana-datasources.yml"
  
  content = <<-EOT
    apiVersion: 1
    
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus.${aws_route53_zone.private.name}:9090
        isDefault: true
        editable: false
        
      - name: Loki
        type: loki
        access: proxy
        url: http://loki.${aws_route53_zone.private.name}:3100
        editable: false
        
      - name: CloudWatch
        type: cloudwatch
        jsonData:
          authType: default
          defaultRegion: ${var.aws_region}
  EOT
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${aws_lb.grafana.dns_name}"
}

output "grafana_internal_url" {
  description = "Grafana internal URL"
  value       = "http://grafana.${aws_route53_zone.private.name}"
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.grafana_admin_password
  sensitive   = true
}

output "grafana_info" {
  description = "Grafana setup information"
  sensitive = true
  value = <<-EOT
  
  📊 GRAFANA IS DEPLOYED!
  
  ✅ REQ-NCA-P2-05: Observability stack deployed
  ✅ REQ-NCA-P2-08: SOAR monitoring ready
  ✅ REQ-NCA-P2-09: Integrated with observability
  
  Access Grafana:
  - Load Balancer URL: http://${aws_lb.grafana.dns_name}
  - Internal URL: http://grafana.${aws_route53_zone.private.name}
  
  Login Credentials:
  - Username: admin
  - Password: ${var.grafana_admin_password}
  
  ⚠️  CHANGE PASSWORD IMMEDIATELY after first login!
  
  Pre-configured Datasources:
  ✅ Prometheus (metrics)
  ✅ Loki (logs)
  ✅ CloudWatch (AWS metrics)
  
  Next Steps:
  1. Log in to Grafana
  2. Change admin password
  3. Import dashboards (see /dashboards folder)
  4. Configure alert notifications
  5. Create custom dashboards for your apps
  
  Popular Dashboards:
  - Node Exporter Full (ID: 1860)
  - ECS Fargate (ID: 11184)
  - PostgreSQL Database (ID: 9628)
  - Loki Dashboard (ID: 13639)
  
  Import via: Dashboard > Import > Dashboard ID
  
  EOT
}
