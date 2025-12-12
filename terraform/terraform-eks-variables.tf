
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "nca-p3"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "production"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "NCA-P3"
    Environment = "production"
    ManagedBy   = "terraform"
    Owner       = "ernie@fontys.nl"
    CostCenter  = "IT-Security"
  }
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "nca-p3-eks-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.28" 
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "kms_key_arn" {
  description = "ARN of KMS key for EKS secret encryption (optional)"
  type        = string
  default     = ""
}

variable "node_instance_types" {
  description = "List of instance types for the node group"
  type        = list(string)
  default     = ["t3.medium"] 
  
}

variable "node_capacity_type" {
  description = "Type of capacity for nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 3 
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 6  
}

variable "node_disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 50
}


variable "vpc_cni_version" {
  description = "Version of VPC CNI add-on"
  type        = string
  default     = "v1.15.0-eksbuild.2"
}

variable "coredns_version" {
  description = "Version of CoreDNS add-on"
  type        = string
  default     = "v1.10.1-eksbuild.6" 
}

variable "kube_proxy_version" {
  description = "Version of kube-proxy add-on"
  type        = string
  default     = "v1.28.2-eksbuild.2"
}

variable "ebs_csi_driver_version" {
  description = "Version of EBS CSI driver add-on"
  type        = string
  default     = "v1.25.0-eksbuild.1"
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 7
}

variable "enable_cluster_logging" {
  description = "Enable cluster control plane logging"
  type        = bool
  default     = true
}
