#!/bin/bash
set -e

# 1. Lấy thông tin từ Terraform output
echo "Extracting Terraform outputs..."
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION="ap-southeast-1"
VPC_ID=$(aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region $REGION \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text)

echo "Cluster Name: $CLUSTER_NAME"
echo "Region:       $REGION"
echo "VPC ID:       $VPC_ID"

# 2. Tạo IAM Policy cho AWS Load Balancer Controller
echo "Creating IAM policy from local file iam_policy.json..."
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json \
  || echo "Policy may already exist, skipping..."

# 3. Liên kết OIDC Provider (nếu chưa có)
echo "Checking OIDC provider for EKS..."
OIDC_ID=$(aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region $REGION \
  --query "cluster.identity.oidc.issuer" \
  --output text | sed -e "s/^https:\/\///")

if ! aws iam list-open-id-connect-providers | grep -q "$OIDC_ID"; then
  echo "OIDC provider not found. Associating it..."
  eksctl utils associate-iam-oidc-provider \
    --region=$REGION \
    --cluster=$CLUSTER_NAME \
    --approve
else
  echo "OIDC provider already exists."
fi

# 4. Tạo IAM ServiceAccount cho Controller
echo "Creating IAM ServiceAccount for ALB Controller..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --region=$REGION \
  --approve

# 5. Cài đặt AWS Load Balancer Controller bằng Helm
echo "Installing AWS Load Balancer Controller via Helm..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$REGION \
  --set vpcId=$VPC_ID

echo "AWS Load Balancer Controller installation complete."
kubectl get deployment -n kube-system aws-load-balancer-controller
