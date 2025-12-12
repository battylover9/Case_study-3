resource "aws_route53_zone" "private" {
  name = "${var.School_network}.internal"

  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = {
    Name = "${var.School_network}-private-zone"
    Requirement = "REQ-NCA-P2-04"
  }
}

resource "aws_route53_record" "database" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "database.${aws_route53_zone.private.name}"
  type    = "CNAME"
  ttl     = 300
  records = ["placeholder.rds.amazonaws.com"]

  lifecycle {
    ignore_changes = [records]
  }
}

resource "aws_route53_record" "prometheus" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "prometheus.${aws_route53_zone.private.name}"
  type    = "A"
  ttl     = 300
  records = ["10.0.11.10"]

  lifecycle {
    ignore_changes = [records]
  }
}

resource "aws_route53_record" "grafana" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "grafana.${aws_route53_zone.private.name}"
  type    = "A"
  ttl     = 300
  records = ["10.0.11.20"]

  lifecycle {
    ignore_changes = [records]
  }
}

resource "aws_route53_record" "loki" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "loki.${aws_route53_zone.private.name}"
  type    = "A"
  ttl     = 300
  records = ["10.0.11.30"]

  lifecycle {
    ignore_changes = [records]
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  
  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id
  )

  tags = {
    Name = "${var.School_network}-s3-endpoint"
    description = "VPC endpoint"
    Requirement = "REQ-NCA-P2-03"
  }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  private_dns_enabled = true

  tags = {
    Name = "${var.School_network}-logs-endpoint"
    Requirement = "REQ-NCA-P2-03, REQ-NCA-P2-04"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  private_dns_enabled = true

  tags = {
    Name = "${var.School_network}-ecr-api-endpoint"
    description = "Pulling container images endpoint"
    Requirement = "REQ-NCA-P2-03"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  private_dns_enabled = true

  tags = {
    Name = "${var.School_network}-ecr-dkr-endpoint"
    description = "Docker VPC endpoint"
    Requirement = "REQ-NCA-P2-03"
  }
}

resource "aws_security_group" "vpc_endpoints" {
  name = "${var.School_network}-vpc-endpoints"
  description      = "Security group for VPC endpoints"
  vpc_id           = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    description = "All traffic outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.School_network}-vpc-endpoints-sg"
  }
}

output "private_zone_id" {
  description = "ID of the private hosted zone"
  value       = aws_route53_zone.private.zone_id
}

output "private_zone_name" {
  description = "Name of the private hosted zone"
  value       = aws_route53_zone.private.name
}

output "dns_name_servers" {
  description = "Name servers for the private zone"
  value       = aws_route53_zone.private.name_servers
}
