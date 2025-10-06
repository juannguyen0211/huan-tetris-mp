variable "aws_profile" {
  description = "Tên AWS CLI profile để sử dụng"
  type        = string
  default     = "juan-devops"
}

variable "aws_region" {
  description = "Vùng AWS để triển khai hạ tầng"
  type        = string
  default     = "ap-southeast-1"
}

variable "cluster_name" {
  description = "Tên của EKS Cluster"
  type        = string
  default     = "huan-tetris-mp-cluster"
}

variable "cluster_version" {
  description = "Phiên bản Kubernetes cho EKS"
  type        = string
  default     = "1.32"
}

variable "vpc_cidr" {
  description = "CIDR block cho VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Danh sách Availability Zones"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "public_subnets" {
  description = "CIDR cho các public subnet"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "private_subnets" {
  description = "CIDR cho các private subnet"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}
