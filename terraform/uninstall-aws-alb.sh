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
ROLE_NAME="eksctl-${SERVICE_ACCOUNT_NAME}-role"

echo "=== STARTING AWS LOAD BALANCER CONTROLLER UNINSTALL ==="
echo "Cluster: $CLUSTER_NAME | Region: $REGION"
echo

# ---------------------------------
# 1. DELETE INGRESS & LOADBALANCER SERVICES
# ---------------------------------
echo "Deleting all Ingresses and LoadBalancer Services..."
kubectl delete ingress --all -A --ignore-not-found
if kubectl get svc -A | grep -q LoadBalancer; then
  kubectl delete svc -A --field-selector spec.type=LoadBalancer --ignore-not-found
else
  echo "No LoadBalancer Services found."
fi
echo

# ---------------------------------
# 2. RETRIEVE VPC ID OF CLUSTER
# ---------------------------------
echo "Retrieving VPC ID from the cluster..."
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
  --query "cluster.resourcesVpcConfig.vpcId" --output text)
echo "VPC ID: $VPC_ID"
echo

# ---------------------------------
# 3. DELETE LOAD BALANCERS AND TARGET GROUPS
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

# Chờ để AWS cleanup xong trước khi xóa Target Group
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
# 4. DELETE ORPHAN SECURITY GROUPS
# ---------------------------------
echo "Deleting orphan Security Groups starting with 'k8s-'..."
SG_IDS=$(aws ec2 describe-security-groups --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=k8s-*" \
  --query "SecurityGroups[].GroupId" --output text)

if [[ -n "$SG_IDS" ]]; then
  for SG_ID in $SG_IDS; do
    echo "  - Deleting Security Group: $SG_ID"
    aws ec2 delete-security-group --region "$REGION" --group-id "$SG_ID" || true
  done
else
  echo "No orphan Security Groups found."
fi
echo

# ---------------------------------
# 5. UNINSTALL HELM RELEASE
# ---------------------------------
echo "Uninstalling Helm release aws-load-balancer-controller..."
helm uninstall aws-load-balancer-controller -n "$SERVICE_ACCOUNT_NAMESPACE" || true
echo

# ---------------------------------
# 6. DELETE SERVICE ACCOUNT
# ---------------------------------
echo "Deleting Service Account $SERVICE_ACCOUNT_NAME..."
kubectl delete sa "$SERVICE_ACCOUNT_NAME" -n "$SERVICE_ACCOUNT_NAMESPACE" --ignore-not-found || true
echo

# ---------------------------------
# 7. DELETE IAM ROLE CREATED BY EKSCTL
# ---------------------------------
echo "Checking for IAM Role created by eksctl..."
ROLE_ARN=$(aws iam list-roles --query "Roles[?contains(RoleName, '$SERVICE_ACCOUNT_NAME')].Arn" --output text)

if [[ -n "$ROLE_ARN" ]]; then
  echo "  - Found Role(s):"
  echo "$ROLE_ARN"
  for ARN in $ROLE_ARN; do
    ROLE_NAME=$(basename "$ARN")
    echo "  - Detaching inline and managed policies from $ROLE_NAME..."
    aws iam list-attached-role-policies --role-name "$ROLE_NAME" \
      --query "AttachedPolicies[].PolicyArn" --output text | while read -r POLICY; do
      [ -z "$POLICY" ] && continue
      aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY" || true
    done
    aws iam delete-role --role-name "$ROLE_NAME" || true
    echo "  - Deleted Role: $ROLE_NAME"
  done
else
  echo "No IAM Role created by eksctl found."
fi
echo

# ---------------------------------
# 8. DELETE IAM POLICY
# ---------------------------------
echo "Deleting IAM Policy $POLICY_NAME (if exists)..."
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

if [[ -n "$POLICY_ARN" ]]; then
  echo "  - Detaching all entities from policy: $POLICY_ARN"

  ROLE_NAMES=$(aws iam list-entities-for-policy --policy-arn "$POLICY_ARN" --query "PolicyRoles[].RoleName" --output text)
  for ROLE in $ROLE_NAMES; do
    echo "    - Detaching from role: $ROLE"
    aws iam detach-role-policy --role-name "$ROLE" --policy-arn "$POLICY_ARN" || true
  done

  USER_NAMES=$(aws iam list-entities-for-policy --policy-arn "$POLICY_ARN" --query "PolicyUsers[].UserName" --output text)
  for USER in $USER_NAMES; do
    echo "    - Detaching from user: $USER"
    aws iam detach-user-policy --user-name "$USER" --policy-arn "$POLICY_ARN" || true
  done

  GROUP_NAMES=$(aws iam list-entities-for-policy --policy-arn "$POLICY_ARN" --query "PolicyGroups[].GroupName" --output text)
  for GROUP in $GROUP_NAMES; do
    echo "    - Detaching from group: $GROUP"
    aws iam detach-group-policy --group-name "$GROUP" --policy-arn "$POLICY_ARN" || true
  done

  echo "  - Deleting policy: $POLICY_ARN"
  aws iam delete-policy --policy-arn "$POLICY_ARN" || true
else
  echo "IAM Policy does not exist."
fi
echo

# ---------------------------------
# 9. DELETE CLOUDFORMATION STACK CREATED BY EKSCTL
# ---------------------------------
STACK_NAME="eksctl-${CLUSTER_NAME}-addon-iamserviceaccount-${SERVICE_ACCOUNT_NAMESPACE}-${SERVICE_ACCOUNT_NAME}"

echo "Checking for CloudFormation stack $STACK_NAME..."
if aws cloudformation describe-stacks --region "$REGION" --stack-name "$STACK_NAME" >/dev/null 2>&1; then
  echo "  - Found stack: $STACK_NAME. Deleting..."
  aws cloudformation delete-stack --region "$REGION" --stack-name "$STACK_NAME"
  echo "  - Waiting for CloudFormation stack to be deleted..."
  aws cloudformation wait stack-delete-complete --region "$REGION" --stack-name "$STACK_NAME"
  echo "✅ CloudFormation stack deleted successfully."
else
  echo "No CloudFormation stack found for AWS Load Balancer Controller."
fi
echo

echo "=== AWS LOAD BALANCER CONTROLLER UNINSTALL COMPLETED SUCCESSFULLY ==="
