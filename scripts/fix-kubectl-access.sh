#!/bin/bash
set -e

CLUSTER_NAME="model-supply-chain-staging"
REGION="us-east-1"
ACCOUNT_ID="050083686295"

echo "=== EKS Cluster Access Fix Script ==="
echo ""

# Step 1: Verify cluster status
echo "1. Checking cluster status..."
CLUSTER_STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text)
echo "   Cluster status: $CLUSTER_STATUS"

if [ "$CLUSTER_STATUS" != "ACTIVE" ]; then
    echo "   ERROR: Cluster is not ACTIVE"
    exit 1
fi

# Step 2: Check current caller identity
echo ""
echo "2. Checking AWS caller identity..."
aws sts get-caller-identity

# Step 3: Update kubeconfig
echo ""
echo "3. Updating kubeconfig..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION --alias eks-$CLUSTER_NAME

# Step 4: Check access entries
echo ""
echo "4. Checking EKS access entries..."
aws eks list-access-entries --cluster-name $CLUSTER_NAME --region $REGION 2>&1 || echo "   Access entries not available"

# Step 5: Verify EKS addons
echo ""
echo "5. Checking EKS addons..."
aws eks list-addons --cluster-name $CLUSTER_NAME --region $REGION

# Step 6: Check node groups
echo ""
echo "6. Checking node groups..."
aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION

# Step 7: List EC2 instances
echo ""
echo "7. Checking EC2 instances (nodes)..."
aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=$CLUSTER_NAME" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]' \
  --output table \
  --region $REGION

# Step 8: Try kubectl
echo ""
echo "8. Testing kubectl access..."
echo "   Attempting: kubectl get svc"
kubectl get svc 2>&1 || {
    echo ""
    echo "   kubectl access FAILED"
    echo ""
    echo "=== Diagnosis ==="
    echo "   The cluster is ACTIVE and nodes are running, but kubectl cannot authenticate."
    echo ""
    echo "   Possible causes:"
    echo "   1. aws-auth ConfigMap not properly configured"
    echo "   2. IAM permissions issue"
    echo "   3. Cluster authentication mode issue"
    echo ""
    echo "   Recommended actions:"
    echo "   A. Create/update aws-auth ConfigMap manually"
    echo "   B. Use EKS access entries (modern approach)"
    echo "   C. Check CloudWatch logs for authentication errors"
    echo ""
    exit 1
}

echo ""
echo "=== Success! kubectl access is working ==="
kubectl get nodes
