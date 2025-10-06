output "eks_cluster_name" {
  description = "Tên của EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint của EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  description = "CA data của EKS cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "eks_node_group_role_arn" {
  description = "IAM role ARN của node group mặc định"
  value       = module.eks.eks_managed_node_groups["default"].iam_role_arn
}

output "vpc_id" {
  description = "ID của VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Danh sách private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Danh sách public subnet IDs"
  value       = module.vpc.public_subnets
}
