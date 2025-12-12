variable "School_network" {
  description = "Name of the project - like naming your toy box"
  type        = string
  default     = "hybrid-cloud-school"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region where we build everything"
  type        = string
  default     = "eu-west-1" 
}

variable "availability_zones" {
  description = "Multiple zones for high availability"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "vpc_cidr" {
  description = "Main VPC network range - the size of your toy box"
  type        = string
  default     = "10.0.0.0/16"  
}

variable "public_subnet_cidrs" {
  description = "Public subnets"
  type        = list(string)
  default     = [
    "10.0.1.0/24",   
    "10.0.2.0/24",   
    "10.0.3.0/24"    
  ]
}

variable "private_subnet_cidrs" {
  description = "Private subnets"
  type        = list(string)
  default     = [
    "10.0.11.0/24",  
    "10.0.12.0/24",  
    "10.0.13.0/24"   
  ]
}

variable "database_subnet_cidrs" {
  description = "Database subnets"
  type        = list(string)
  default     = [
    "10.0.21.0/24",
    "10.0.22.0/24",
    "10.0.23.0/24"
  ]
}

variable "on_prem_cidr" {
  description = "Your school/home network range"
  type        = string
  default     = "192.168.0.0/16"  
}

variable "on_prem_vpn_ip" {
  description = "Public IP of your on-premises VPN gateway"
  type        = string
  default     = "144.178.197.106"
}

variable "ecs_task_cpu" {
  description = "CPU units for ECS tasks (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Memory for ECS tasks in MB"
  type        = number
  default     = 512
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana dashboard"
  type        = string
  sensitive   = true
  default     = "B@ker1234"
}

variable "prometheus_retention_days" {
  description = "How many days to keep metrics"
  type        = number
  default     = 15
}

variable "soar_alert_email" {
  description = "Email to receive SOAR alerts"
  type        = string
  default     = "456055@student.fontys.nl"
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "Hybrid-Cloud-School"
    ManagedBy   = "Terraform"
    Environment = "Development"
    Owner       = "Ernie"
  }
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway"
  type        = bool
  default     = true
}

variable "nat_gateway_count" {
  description = "Number of NAT gateways"
  type        = number
  default     = 1
}

variable "allowed_ssh_ips" {
  description = "IP addresses allowed to SSH into servers"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC flow logs for security monitoring"
  type        = bool
  default     = true
}
