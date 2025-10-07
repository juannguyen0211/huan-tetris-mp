#!/bin/bash
set -euo pipefail

# ---------------------------------
# Configuration
# ---------------------------------
CLUSTER_NAME="${CLUSTER_NAME:-huan-tetris-cluster}"
REGION="${REGION:-ap-southeast-1}"
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
SERVICE_ACCOUNT_NAMESPACE="kube-system"
SERVICE_ACCOUNT_NAME="aws-load-balancer-controller"

echo "=== STARTING UNINSTALL OF AWS LOAD BALANCER CONTROLLER ==="
echo "Cluster: $CLUSTER_NAME | Region: $REGION"
echo

# ---------------------------------
# 1. XÓA INGRESS & SERVICE
# ---------------------------------
echo "Deleting all Ingresses and LoadBalancer Services..."
kubectl delete ingress --all -A --ignore-not-found
kubectl get svc -A | grep LoadBalancer && \
kubectl delete svc -A --field-selector spec.type=LoadBalancer --ignore-not-found || \
echo "No LoadBalancer Services found."
echo

# ---------------------------------
# 2. LẤY VPC ID CỦA CLUSTER
# ---------------------------------
echo "Retrieving VPC ID from the cluster..."
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
  --query "cluster.resourcesVpcConfig.vpcId" --output text)
echo "VPC ID: $VPC_ID"
echo

# ---------------------------------
# 3. XÓA ALB VÀ TARGET GROUP
# ---------------------------------
echo "Deleting Load Balancers in VPC $VPC_ID..."
LB_ARNS=$(aws elbv2 describe-load-balancers --region "$REGION" \
  --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text)

if [[ -n "$LB_ARNS" ]]; then
  for LB_ARN in $LB_ARNS; do
    echo "  - Deleting Load Balancer: $LB_ARN"
    aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$LB_ARN" || true
  done
else
  echo "No Load Balancers found in this VPC."
fi
echo

sleep 20

echo "Deleting orphan Target Groups..."
TG_ARNS=$(aws elbv2 describe-target-groups --region "$REGION" \
  --query "TargetGroups[?VpcId=='$VPC_ID'].TargetGroupArn" --output text)

if [[ -n "$TG_ARNS" ]]; then
  for TG_ARN in $TG_ARNS; do
    echo "  - Deleting Target Group: $TG_ARN"
    aws elbv2 delete-target-group --region "$REGION" --target-group-arn "$TG_ARN" || true
  done
else
  echo "No Target Groups to delete."
fi
echo

# ---------------------------------
# 4. XÓA SECURITY GROUP MỒ CÔI
# ---------------------------------
echo "Deleting orphan Security Groups starting with 'k8s-' in VPC..."
SG_IDS=$(aws ec2 describe-security-groups --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=k8s-*" \
  --query "SecurityGroups[].GroupId" --output text)

if [[ -n "$SG_IDS" ]]; then
  for SG_ID in $SG_IDS; do
    echo "  - Deleting Security Group: $SG_ID"
    aws ec2 delete-security-group --region "$REGION" --group-id "$SG_ID" || true
  done
else
  echo "No Security Groups to delete."
fi
echo

# ---------------------------------
# 5. GỠ HELM RELEASE
# ---------------------------------
echo "Uninstalling Helm release aws-load-balancer-controller..."
helm uninstall aws-load-balancer-controller -n "$SERVICE_ACCOUNT_NAMESPACE" || true
echo

# ---------------------------------
# 6. XÓA SERVICE ACCOUNT
# ---------------------------------
echo "Deleting Service Account $SERVICE_ACCOUNT_NAME..."
kubectl delete sa "$SERVICE_ACCOUNT_NAME" -n "$SERVICE_ACCOUNT_NAMESPACE" --ignore-not-found || true
echo

# ---------------------------------
# 7. XÓA IAM POLICY
# ---------------------------------
echo "Deleting IAM Policy $POLICY_NAME (if exists)..."
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)
if [[ -n "$POLICY_ARN" ]]; then
  echo "  - Deleting policy: $POLICY_ARN"
  aws iam delete-policy --policy-arn "$POLICY_ARN" || true
else
  echo "IAM Policy does not exist."
fi
echo

echo "=== UNINSTALL COMPLETED ==="
