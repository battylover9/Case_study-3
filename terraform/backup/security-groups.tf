resource "aws_security_group" "web" {
  name = "${var.School_network}-web-sg"
  description      = "Security group for web (load balancers)"
  vpc_id           = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.School_network}-web-sg"
    tier = "Web"
    Requirement = "REQ-NCA-P2-02"
  }
}


resource "aws_security_group" "app" {
  name = "${var.School_network}-app-sg"
  description      = "Security group for application (ECS, EC2)"
  vpc_id           = aws_vpc.main.id

  ingress {
    description     = "Traffic from web"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    description = "Traffic from other app instances"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true  # Allow traffic from same security group
  }

  ingress {
    description     = "Traffic from on-premises via VPN"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.vpn_access.id]
  }

  ingress {
    description     = "SSH for debugging admin"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.admin.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.School_network}-app-sg"
    tier = "Application"
    Requirement = "REQ-NCA-P2-02"
  }
}

resource "aws_security_group" "database" {
  name = "${var.School_network}-database-sg"
  description      = "Security group for RDS"
  vpc_id           = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from app"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description     = "PostgreSQL from monitoring"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring.id]
  }

  ingress {
    description     = "PostgreSQL from admin"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.admin.id]
  }

  egress {
    description = "Outbound to VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "${var.School_network}-database-sg"
    tier = "Database"
    Requirement = "REQ-NCA-P2-03"
  }
}


resource "aws_security_group" "monitoring" {
  name = "${var.School_network}-monitoring-sg"
  description      = "Security group for monitoring"
  vpc_id           = aws_vpc.main.id

  ingress {
    description     = "Prometheus from app"
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description     = "Grafana from web"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    description     = "Grafana from on-premises"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.vpn_access.id]
  }

  ingress {
    description     = "Loki from app"
    from_port       = 3100
    to_port         = 3100
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description = "Node exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.School_network}-monitoring-sg"
    Description = "Monitoring"
    Requirement = "REQ-NCA-P2-05, REQ-NCA-P2-08"
  }
}

resource "aws_security_group" "soar" {
  name = "${var.School_network}-soar-sg"
  description      = "Security group for lambda functions"
  vpc_id           = aws_vpc.main.id


  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.School_network}-soar-sg"
    tier = "SOAR"
    Requirement = "REQ-NCA-P2-06, REQ-NCA-P2-07"
  }
}

resource "aws_security_group" "admin" {
  name = "${var.School_network}-admin-sg"
  description      = "Security group for admin host"
  vpc_id           = aws_vpc.main.id

  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_ips
  }

  ingress {
    description = "SSH from on-premises"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.on_prem_cidr]
  }

  egress {
    description = "Outbound to VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "${var.School_network}-admin-sg"
    tier = "Management"
  }
}

output "security_group_ids" {
  description = "Map of all security group IDs"
  value = {
    web        = aws_security_group.web.id
    app        = aws_security_group.app.id
    database   = aws_security_group.database.id
    monitoring = aws_security_group.monitoring.id
    soar       = aws_security_group.soar.id
    admin    = aws_security_group.admin.id
    vpn_access = aws_security_group.vpn_access.id
  }
}
