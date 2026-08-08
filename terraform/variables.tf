variable "project_name" {
  description = "Project name used for naming resources"
  type        = string
  default     = "model-supply-chain"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Must be staging or production."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.33"  # Current stable version with full support
}

variable "system_node_instance_type" {
  description = "EC2 instance type for system nodes"
  type        = string
  default     = "t3.medium"
}

variable "ml_node_instance_type" {
  description = "EC2 instance type for ML workloads"
  type        = string
  default     = "t3.xlarge"
}

variable "ml_node_min" {
  description = "Min ML nodes"
  type        = number
  default     = 1
}

variable "ml_node_max" {
  description = "Max ML nodes (autoscaling)"
  type        = number
  default     = 5
}

variable "ml_node_desired" {
  description = "Desired ML nodes"
  type        = number
  default     = 2
}
