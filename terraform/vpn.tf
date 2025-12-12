
resource "aws_customer_gateway" "main" {
  ip_address = var.on_prem_vpn_ip
  type       = "ipsec.1"

  tags = {
    Name = "${var.School_network}-customer-gateway"
    description = "Door to on prem"
  }
}

resource "aws_vpn_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {    Name = "${var.School_network}-vpn-gateway"
    description = "Door to Cloud"
  }
}

resource "aws_vpn_gateway_attachment" "main" {
  vpc_id         = aws_vpc.main.id
  vpn_gateway_id = aws_vpn_gateway.main.id
}
resource "aws_vpn_connection" "main" {
  vpn_gateway_id      = aws_vpn_gateway.main.id
  customer_gateway_id = aws_customer_gateway.main.id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = {
    Name = "${var.School_network}-vpn-connection"
    Requirement = "REQ-NCA-P2-02"
  }
}

resource "aws_vpn_connection_route" "on_prem" {
  destination_cidr_block = var.on_prem_cidr
  vpn_connection_id      = aws_vpn_connection.main.id
}

resource "aws_vpn_gateway_route_propagation" "private" {
  count          = length(aws_route_table.private)
  vpn_gateway_id = aws_vpn_gateway.main.id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_vpn_gateway_route_propagation" "public" {
  vpn_gateway_id = aws_vpn_gateway.main.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "vpn_access" {
  name = "${var.School_network}-vpn-access"
  description = "Allow traffic from on-premises network through VPN"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "All traffic from on-premises"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = [var.on_prem_cidr]
  }

  egress {    
    description = "All traffic to on-premises"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.on_prem_cidr]
  }

  tags = {    Name = "${var.School_network}-vpn-access-sg"
    description = "Allow inbound and outbound traffic to and from on-prem"
  }
}

output "vpn_connection_id" {
  description = "ID of the VPN connection"
  value       = aws_vpn_connection.main.id
}
output "customer_gateway_configuration" {
  description = "Configuration to paste into your on-prem VPN device"
  value       = aws_vpn_connection.main.customer_gateway_configuration
  sensitive   = true
}

output "vpn_tunnel1_address" {
 description = "Public IP of VPN tunnel 1"
  value       = aws_vpn_connection.main.tunnel1_address
}

output "vpn_tunnel2_address" {
  description = "Public IP of VPN tunnel 2"
  value       = aws_vpn_connection.main.tunnel2_address
}
output "vpn_tunnel1_preshared_key" {
  description = "Pre-shared key for tunnel 1"
  value       = aws_vpn_connection.main.tunnel1_preshared_key
  sensitive   = true
  }

output "vpn_tunnel2_preshared_key" {
 description = "Pre-shared key for tunnel 2"
  value       = aws_vpn_connection.main.tunnel2_preshared_key
  sensitive   = true
}
