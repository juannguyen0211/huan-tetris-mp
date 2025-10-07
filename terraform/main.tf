###############################################################################
# VPC & Networking
###############################################################################
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-southeast-1b"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.rt.id
}

###############################################################################
# IAM Roles
###############################################################################
# Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "huan-tetris-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# Role for EKS Nodes
resource "aws_iam_role" "eks_nodes_role" {
  name = "huan-tetris-eks-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes_role.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes_role.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes_role.name
}

###############################################################################
# EKS Cluster
###############################################################################
resource "aws_eks_cluster" "huan_tetris" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.30"

  vpc_config {
    subnet_ids = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSServicePolicy
  ]
}

###############################################################################
# aws-auth ConfigMap (for node group authentication)
###############################################################################
resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([{
      rolearn  = aws_iam_role.eks_nodes_role.arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    }])
  }

  depends_on = [aws_eks_cluster.huan_tetris]
}

###############################################################################
# EKS Node Group
###############################################################################
resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.huan_tetris.name
  node_group_name = "huan-tetris-nodes"
  node_role_arn   = aws_iam_role.eks_nodes_role.arn
  subnet_ids      = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  instance_types  = ["c7i-flex.large"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 2
  }

  depends_on = [
    kubernetes_config_map.aws_auth,
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly
  ]
}

###############################################################################
# Generate kubeconfig file automatically
###############################################################################
resource "local_file" "kubeconfig" {
  content = templatefile("${path.module}/templates/kubeconfig.tpl", {
    cluster_name = aws_eks_cluster.huan_tetris.name
    endpoint     = aws_eks_cluster.huan_tetris.endpoint
    ca_data      = aws_eks_cluster.huan_tetris.certificate_authority[0].data
  })
  filename = "${path.module}/kubeconfig_${aws_eks_cluster.huan_tetris.name}"
}
