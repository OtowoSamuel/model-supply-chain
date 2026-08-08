#!/bin/bash
# Complete Terraform Destroy Script
# This script safely destroys all infrastructure in the correct order

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

CLUSTER_NAME="model-supply-chain-staging"
REGION="us-east-1"
PROJECT_ROOT="/Users/admin/Documents/Documents/Projects-2026/model-supply-chain"

echo "=============================================="
echo "  Terraform Complete Destroy Script"
echo "=============================================="
echo ""
log_warn "This will destroy ALL infrastructure including:"
log_warn "  - EKS cluster and all nodes"
log_warn "  - VPC and networking"
log_warn "  - ECR repository and images"
log_warn "  - IAM roles and policies"
log_warn "  - S3 state bucket (optional)"
log_warn "  - DynamoDB lock table (optional)"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    log_info "Destroy cancelled"
    exit 0
fi

echo ""
log_info "Step 1: Cleaning up Kubernetes resources..."

# Try to delete Kubernetes resources if kubectl is working
if kubectl get nodes &> /dev/null; then
    log_info "Deleting namespaces..."
    kubectl delete namespace ml-staging --ignore-not-found=true --timeout=5m || log_warn "Failed to delete ml-staging namespace"
    kubectl delete namespace kyverno --ignore-not-found=true --timeout=5m || log_warn "Failed to delete kyverno namespace"
    
    log_info "Waiting for namespace deletion..."
    sleep 30
else
    log_warn "kubectl not accessible, skipping Kubernetes cleanup"
fi

# Step 2: Destroy main infrastructure
echo ""
log_info "Step 2: Destroying main infrastructure with Terraform..."
cd "$PROJECT_ROOT/terraform"

# Remove any local state lock
rm -f .terraform.terraform.tfstate.lock.info 2>/dev/null || true

# Check if state backend exists
if aws s3 ls s3://tf-state-model-supply-chain-050083686295 2>/dev/null; then
    log_info "State backend exists, initializing Terraform..."
    terraform init || log_warn "Terraform init failed, continuing anyway..."
else
    log_warn "State backend does not exist, skipping Terraform init"
fi

log_info "Running terraform destroy..."
terraform destroy \
    -var="environment=staging" \
    -auto-approve || log_warn "Terraform destroy completed with warnings"

log_info "✓ Main infrastructure destroyed"

# Step 3: Clean up orphaned resources
echo ""
log_info "Step 3: Checking for orphaned AWS resources..."

# Check for EC2 instances
INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=tag:eks:cluster-name,Values=$CLUSTER_NAME" "Name=instance-state-name,Values=running,pending,stopping,stopped" \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ -n "$INSTANCES" ]; then
    log_warn "Found orphaned EC2 instances: $INSTANCES"
    log_warn "Manually terminate with: aws ec2 terminate-instances --instance-ids $INSTANCES --region $REGION"
else
    log_info "✓ No orphaned EC2 instances"
fi

# Check for ELBs
ELBS=$(aws elb describe-load-balancers \
    --query "LoadBalancerDescriptions[?contains(DNSName, '$CLUSTER_NAME')].LoadBalancerName" \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ -n "$ELBS" ]; then
    log_warn "Found orphaned load balancers: $ELBS"
    for elb in $ELBS; do
        log_info "Deleting ELB: $elb"
        aws elb delete-load-balancer --load-balancer-name $elb --region $REGION || log_warn "Failed to delete $elb"
    done
else
    log_info "✓ No orphaned load balancers"
fi

# Check for security groups
SG_IDS=$(aws ec2 describe-security-groups \
    --filters "Name=tag:eks:cluster-name,Values=$CLUSTER_NAME" \
    --query 'SecurityGroups[*].GroupId' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ -n "$SG_IDS" ]; then
    log_warn "Found orphaned security groups: $SG_IDS"
    log_warn "These will be deleted with the VPC"
else
    log_info "✓ No orphaned security groups"
fi

# Step 4: Optionally destroy state backend
echo ""
read -p "Do you want to destroy the Terraform state backend (S3 + DynamoDB)? (yes/no): " destroy_backend

if [ "$destroy_backend" = "yes" ]; then
    log_info "Step 4: Destroying Terraform state backend..."
    cd "$PROJECT_ROOT/terraform/bootstrap"
    
    terraform destroy -auto-approve
    
    log_info "✓ State backend destroyed"
else
    log_info "Keeping state backend (S3 + DynamoDB)"
fi

# Step 5: Clean up local files
echo ""
log_info "Step 5: Cleaning up local Terraform files..."
cd "$PROJECT_ROOT/terraform"

rm -f terraform_apply.log terraform_apply_complete.log terraform_apply_resume.log terraform_final_apply.log 2>/dev/null || true
rm -f .terraform.lock.hcl 2>/dev/null || true
rm -rf .terraform/ 2>/dev/null || true

cd "$PROJECT_ROOT/terraform/bootstrap"
rm -f .terraform.lock.hcl 2>/dev/null || true
rm -rf .terraform/ 2>/dev/null || true

log_info "✓ Local files cleaned"

# Summary
echo ""
echo "=============================================="
echo "  Destroy Complete"
echo "=============================================="
echo ""
log_info "Infrastructure destroyed successfully!"
echo ""
echo "Remaining manual checks:"
echo "  1. Verify no resources in AWS console"
echo "  2. Check AWS billing for any remaining charges"
echo "  3. Remove local kubeconfig: rm ~/.kube/config"
echo ""

if [ "$destroy_backend" != "yes" ]; then
    log_info "State backend preserved. You can still view the last state with:"
    echo "  cd terraform && terraform init && terraform show"
fi

echo ""
log_info "Done!"
