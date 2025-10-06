variable "region" {
  description = "AWS region to deploy EKS cluster"
  type        = string
  default     = "ap-southeast-1"
}

variable "profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "juan-devops"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "huan-tetris-mp-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.32"
}

variable "node_instance_types" {
  description = "EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "mock-project"
    Owner       = "Juan"
  }
}
