data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


resource "tls_private_key" "monitoring" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "monitoring" {
  key_name   = "${var.School_network}-monitoring-key"
  public_key = tls_private_key.monitoring.public_key_openssh

  tags = {
    Name = "${var.School_network}-monitoring-key"
  }
}


resource "local_file" "monitoring_private_key" {
  content         = tls_private_key.monitoring.private_key_pem
  filename        = "${path.module}/../../ansible/keys/monitoring-key.pem"
  file_permission = "0600"
}

resource "aws_iam_role" "monitoring" {
  name = "${var.School_network}-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.School_network}-monitoring-role"
  }
}

resource "aws_iam_role_policy" "monitoring" {
  name = "${var.School_network}-monitoring-policy"
  role = aws_iam_role.monitoring.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:DescribeAlarms",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ecs:ListClusters",
          "ecs:ListServices",
          "ecs:DescribeServices",
          "ecs:DescribeTasks",
          "rds:DescribeDBInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.School_network}-monitoring-*",
          "arn:aws:s3:::${var.School_network}-monitoring-*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "monitoring" {
  name = "${var.School_network}-monitoring-profile"
  role = aws_iam_role.monitoring.name

  tags = {
    Name = "${var.School_network}-monitoring-profile"
  }
}

resource "aws_ebs_volume" "monitoring_data" {
  availability_zone = var.availability_zones[0]
  size              = 50
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${var.School_network}-monitoring-data"
  }
}

resource "aws_instance" "monitoring" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.medium" 
  
  subnet_id                   = aws_subnet.private[0].id
  vpc_security_group_ids      = [aws_security_group.monitoring.id]
  iam_instance_profile        = aws_iam_instance_profile.monitoring.name
  key_name                    = aws_key_pair.monitoring.key_name
  associate_public_ip_address = false

  root_block_device {
    volume_size           = 20 
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              # Update system
              yum update -y
              
              # Install Docker
              yum install -y docker
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ec2-user
              
              # Install Docker Compose
              curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose
              
              # Create directories for monitoring stack
              mkdir -p /monitoring/{prometheus,grafana,loki}
              mkdir -p /data/{prometheus,grafana,loki}
              
              # Install CloudWatch agent for system metrics
              wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
              rpm -U ./amazon-cloudwatch-agent.rpm
              
              # Signal that instance is ready
              echo "Monitoring instance ready" > /tmp/ready
              EOF

  tags = {
    Name = "${var.School_network}-monitoring-server"
    Type = "Monitoring"
    Requirement = "REQ-NCA-P2-05_REQ-NCA-P2-08, REQ-NCA-P2-09"
    AnsibleGroup = "monitoring"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_volume_attachment" "monitoring_data" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.monitoring_data.id
  instance_id = aws_instance.monitoring.id
}

resource "aws_s3_bucket" "loki_storage" {
  bucket = "${var.School_network}-loki-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.School_network}-loki-storage"
  }
}

resource "aws_s3_bucket_versioning" "loki_storage" {
  bucket = aws_s3_bucket.loki_storage.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki_storage" {
  bucket = aws_s3_bucket.loki_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "loki_storage" {
  bucket = aws_s3_bucket.loki_storage.id

  rule {
    id     = "archive-old-logs"
    status = "Enabled"

     filter {
      prefix = ""
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

output "monitoring_instance_id" {
  description = "ID of the monitoring EC2 instance"
  value       = aws_instance.monitoring.id
}

output "monitoring_private_ip" {
  description = "Private IP of monitoring server"
  value       = aws_instance.monitoring.private_ip
}

output "prometheus_url" {
  description = "Internal URL for Prometheus"
  value       = "http://prometheus.${aws_route53_zone.private.name}:9090"
}


output "loki_url" {
  description = "Internal URL for Loki"
  value       = "http://loki.${aws_route53_zone.private.name}:3100"
}

output "monitoring_ssh_key_path" {
  description = "Path to SSH private key for monitoring server"
  value       = local_file.monitoring_private_key.filename
}

output "loki_s3_bucket" {
  description = "S3 bucket for Loki long-term storage"
  value       = aws_s3_bucket.loki_storage.id
}

