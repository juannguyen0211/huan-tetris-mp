output "cluster_name" {
  description = "EKS Cluster name"
  value       = aws_eks_cluster.huan_tetris.name
}

output "cluster_endpoint" {
  description = "EKS Cluster API endpoint"
  value       = aws_eks_cluster.huan_tetris.endpoint
}

output "kubeconfig" {
  description = "Generated kubeconfig file path"
  value       = "${path.module}/kubeconfig_${aws_eks_cluster.huan_tetris.name}"
}
