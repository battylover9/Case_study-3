
variable "vpc_id" {
  description = "ID of the VPC (from network module)"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of public subnets (from network module)"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "IDs of private subnets (from network module)"
  type        = list(string)
}

variable "db_subnet_group_name" {
  description = "Name of the database subnet group (from network module)"
  type        = string
}

variable "security_group_ids" {
  description = "Map of security group IDs (from network module)"
  type        = map(string)
}

variable "private_zone_id" {
  description = "ID of the private hosted zone (from network module)"
  type        = string
}

variable "private_zone_name" {
  description = "Name of the private hosted zone (from network module)"
  type        = string
}


variable "School_network" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "ecs_task_cpu" {
  description = "CPU units for ECS tasks"
  type        = number
}

variable "ecs_task_memory" {
  description = "Memory for ECS tasks in MB"
  type        = number
}
