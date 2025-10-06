terraform {
  required_version = ">= 1.3.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.13.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
  }
}

provider "aws" {
  profile = "juan-devops"
  region  = "ap-southeast-1"
}

data "aws_caller_identity" "current" {}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  name    = "tetris-vpc"
  cidr    = "10.0.0.0/16"
  azs     = ["ap-southeast-1a", "ap-southeast-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
}

# EKS Cluster
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "21.3.1" # add version
  name            = "huan-tetris-mp-cluster" # change cluster_name to name
  kubernetes_version = "1.32" # change cluster_version to kubernetes_version
  subnet_ids         = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  enable_irsa     = true
  
  eks_managed_node_groups = {
    default = {
      desired_size     = 2
      max_size     = 3
      min_size     = 1
      instance_types   = ["t3.medium"]
      #capacity_type    = "ON_DEMAND" # comment this out
    }
  }
  #manage_aws_auth = true # comment this out

  tags = {
    Environment = "dev" # change env to Environment
    #Owner       = "Juan" # comment this out
  }
}

# IAM Policy for AWS Load Balancer Controller
resource "aws_iam_policy" "alb_ingress_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "Policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/iam/alb-ingress-policy.json")
}

# IAM Role for ALB Controller
resource "aws_iam_role" "alb_ingress_role" {
  name = "eks-alb-ingress-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "alb_ingress_attach" {
  role       = aws_iam_role.alb_ingress_role.name
  policy_arn = aws_iam_policy.alb_ingress_policy.arn
}

# Output
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "node_group_role_arn" {
  value = module.eks.node_group_iam_role_arn
}
