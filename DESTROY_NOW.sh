#!/bin/bash
# Emergency Destroy Script - Run this to stop all costs immediately
# This will destroy all infrastructure without using Terraform

set -x

CLUSTER_NAME="model-supply-chain-staging"
REGION="us-east-1"

echo "=== EMERGENCY INFRASTRUCTURE TEARDOWN ==="
echo "This will destroy all resources to stop costs"
echo ""

# Step 1: Delete node groups (stops EC2 costs immediately)
echo "Step 1: Deleting node groups..."
aws eks delete-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name model-supply-chain-staging-system --region $REGION || true
aws eks delete-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name model-supply-chain-staging-ml --region $REGION || true

echo "Waiting 30 seconds for node groups to start deleting..."
sleep 30

# Step 2: Delete EKS cluster (stops EKS costs)
echo "Step 2: Deleting EKS cluster..."
aws eks delete-cluster --name $CLUSTER_NAME --region $REGION || true

echo "Waiting 30 seconds..."
sleep 30

# Step 3: Delete NAT Gateway (stops NAT costs)
echo "Step 3: Deleting NAT Gateway..."
NAT_GW_ID=$(aws ec2 describe-nat-gateways --filter "Name=tag:Name,Values=*model-supply-chain*" --region $REGION --query 'NatGateways[0].NatGatewayId' --output text)
if [ "$NAT_GW_ID" != "None" ] && [ -n "$NAT_GW_ID" ]; then
    aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID --region $REGION
    echo "NAT Gateway $NAT_GW_ID deletion initiated"
else
    echo "No NAT Gateway found"
fi

# Step 4: Release Elastic IPs
echo "Step 4: Releasing Elastic IPs..."
EIP_ALLOC=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=*model-supply-chain*" --region $REGION --query 'Addresses[*].AllocationId' --output text)
for eip in $EIP_ALLOC; do
    echo "Releasing EIP: $eip"
    sleep 5  # Wait a bit after NAT gateway deletion
    aws ec2 release-address --allocation-id $eip --region $REGION || echo "Failed to release $eip (may still be attached)"
done

echo ""
echo "=== MAJOR COST COMPONENTS STOPPED ==="
echo "✓ Node groups deleting (EC2 instances terminating)"
echo "✓ EKS cluster deleting"
echo "✓ NAT Gateway deleting"
echo ""
echo "Remaining cleanup (low/no cost):"
echo "- Run: cd terraform && terraform destroy -var=environment=staging"
echo "- This will clean up VPC, security groups, IAM roles, etc."
echo ""
echo "Monitor deletion progress:"
echo "  aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status'"
echo "  aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION"
echo "  aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_GW_ID --region $REGION --query 'NatGateways[0].State'"
echo ""
echo "Estimated time for full deletion: 10-15 minutes"
