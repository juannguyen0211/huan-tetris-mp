output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security group ID of the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

#output "eks_node_group_role_arn" {
#  description = "IAM role ARN for the node group"
#  value       = module.eks.node_groups["default"].iam_role_arn
#}

#output "all_node_group_role_arns" {
#  value = [for ng in keys(module.eks.node_groups) : module.eks.node_groups[ng].iam_role_arn]
#}

output "eks_node_group_role_arn" {
  value = module.eks.eks_managed_node_groups["default"].iam_role_arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}
