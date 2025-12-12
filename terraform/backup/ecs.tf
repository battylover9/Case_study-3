
resource "aws_ecs_cluster" "main" {
  name = "${var.School_network}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.School_network}-ecs-cluster"
    Requirement = "REQ-NCA-P2-01, REQ-NCA-P2-07"
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.School_network}"
  retention_in_days = 7

  tags = {
    Name = "${var.School_network}-ecs-logs"
  }
}

resource "aws_iam_role" "ecs_execution" {
  name = "${var.School_network}-ecs-execution-role"

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
    Name = "${var.School_network}-ecs-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_execution_custom" {
  name = "${var.School_network}-ecs-execution-custom"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# 🎭 ECS Task Role (What containers can do)
resource "aws_iam_role" "ecs_task" {
  name = "${var.School_network}-ecs-task-role"

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
    Name = "${var.School_network}-ecs-task-role"
  }
}

# 📜 Task role policy (access to S3, DynamoDB, etc.)
resource "aws_iam_role_policy" "ecs_task" {
  name = "${var.School_network}-ecs-task-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.School_network}-*",
          "arn:aws:s3:::${var.School_network}-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# ═══════════════════════════════════════════════════════════════
# ⚖️ APPLICATION LOAD BALANCER - Traffic distributor
# REQ-NCA-P2-01: Distributes load, handles failures
# ═══════════════════════════════════════════════════════════════

resource "aws_lb" "main" {
  name               = "${var.School_network}-alb"
  internal           = false  # Public-facing
  load_balancer_type = "application"
  security_groups    = [var.security_group_ids["web"]]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false  # Set true in production
  enable_http2              = true

  tags = {
    Name = "${var.School_network}-alb"
    Requirement = "REQ-NCA-P2-01"  # High availability
  }
}

# 🎯 Target Group - Where ALB sends traffic
resource "aws_lb_target_group" "app" {
  name        = "${var.School_network}-app-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"  # For Fargate

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"  # Your app should have this endpoint
    matcher             = "200"
  }

  deregistration_delay = 30  # How long to wait before removing unhealthy targets

  tags = {
    Name = "${var.School_network}-app-tg"
  }
}

# 👂 ALB Listener - HTTP (redirect to HTTPS in production)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# 💡 For HTTPS, you'd need:
# - ACM certificate
# - Route53 domain
# - Another listener on port 443

# ═══════════════════════════════════════════════════════════════
# 📋 ECS TASK DEFINITION - Container blueprint
# ═══════════════════════════════════════════════════════════════

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.School_network}-app"
  network_mode             = "awsvpc"  # Each task gets its own network
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "app"
      image = "nginx:latest"  # Replace with your actual image
      
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        },
        {
          name  = "DB_HOST"
          value = "database.${var.private_zone_name}"  # Use DNS name
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }

      healthCheck = {
        command = ["CMD-SHELL", "curl -f http://localhost/health || exit 1"]
        interval = 30
        timeout = 5
        retries = 3
      }
    }
  ])

  tags = {
    Name = "${var.School_network}-app-task"
  }
}

# ═══════════════════════════════════════════════════════════════
# 🚀 ECS SERVICE - Keeps containers running
# REQ-NCA-P2-01: Auto-recovery and high availability
# ═══════════════════════════════════════════════════════════════

resource "aws_ecs_service" "app" {
  name            = "${var.School_network}-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2  # Run 2 copies for high availability
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.security_group_ids["app"]]
    assign_public_ip = false  # Private subnet, uses NAT for internet
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 80
  }



  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_execution
  ]

  tags = {
    Name = "${var.School_network}-app-service"
    Requirement = "REQ-NCA-P2-01" 
  }
}

# ═══════════════════════════════════════════════════════════════
# 📊 AUTO SCALING - Scale up/down based on load
# REQ-NCA-P2-01: Handle failures and peak loads
# ═══════════════════════════════════════════════════════════════

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 10  # Maximum 10 tasks
  min_capacity       = 2   # Minimum 2 tasks
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# 📈 Scale up when CPU is high
resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.School_network}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0  # Keep CPU around 70%
    scale_in_cooldown  = 300  # Wait 5 min before scaling down
    scale_out_cooldown = 60   # Wait 1 min before scaling up again
  }
}

# 📊 Scale up when memory is high
resource "aws_appautoscaling_policy" "memory" {
  name               = "${var.School_network}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# ═══════════════════════════════════════════════════════════════
# 📤 OUTPUTS
# ═══════════════════════════════════════════════════════════════

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_url" {
  description = "URL to access your application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}
