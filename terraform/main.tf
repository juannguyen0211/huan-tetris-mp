terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.13.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.token.token
  }
}

data "aws_eks_cluster_auth" "token" {
  name = module.eks.cluster_name
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  name    = "tetris-vpc"
  cidr    = var.vpc_cidr
  azs     = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  enable_nat_gateway = true
  single_nat_gateway = true
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster_name
  cluster_version = "1.27"
  subnets         = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  enable_irsa     = true
  manage_aws_auth = true

  eks_managed_node_groups = {
    default = {
      desired_capacity = 2
      max_capacity     = 3
      min_capacity     = 1
      instance_types   = ["t3.medium"]
      labels = {
        role = "worker"
      }
    }
  }

  tags = {
    Environment = "mock-project"
    Owner       = "Juan"
  }
}

resource "aws_iam_policy" "alb_ingress_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "Policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/iam/alb-ingress-policy.json")
}

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

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.6.2"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  depends_on = [module.eks]
}
