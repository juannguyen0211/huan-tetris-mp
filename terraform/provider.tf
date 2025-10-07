terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

# EKS cluster data sources for kubeconfig
data "aws_eks_cluster" "huan_tetris" {
  name = aws_eks_cluster.huan_tetris.name
}

data "aws_eks_cluster_auth" "huan_tetris" {
  name = aws_eks_cluster.huan_tetris.name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.huan_tetris.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.huan_tetris.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.huan_tetris.token
}
