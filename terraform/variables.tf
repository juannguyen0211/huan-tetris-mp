variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "huan-tetris-cluster"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}
