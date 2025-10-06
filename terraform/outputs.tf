output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = module.eks.cluster_version
}

output "node_group_role_arn" {
  description = "IAM role ARN for node group"
  value       = module.eks.eks_managed_node_groups["default"].iam_role_arn
}
