#!/bin/bash
# Complete Infrastructure Setup Script
# This script completes the EKS cluster setup after initial deployment

set -euo pipefail

CLUSTER_NAME="model-supply-chain-staging"
REGION="us-east-1"
ACCOUNT_ID="050083686295"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check command success
check_success() {
    if [ $? -eq 0 ]; then
        log_info "✓ $1"
    else
        log_error "✗ $1"
        return 1
    fi
}

echo "=============================================="
echo "  EKS Infrastructure Completion Script"
echo "  Cluster: $CLUSTER_NAME"
echo "  Region: $REGION"
echo "=============================================="
echo ""

# Step 1: Verify prerequisites
log_info "Step 1: Verifying prerequisites..."
aws --version > /dev/null 2>&1
check_success "AWS CLI installed"

kubectl version --client > /dev/null 2>&1
check_success "kubectl installed"

aws sts get-caller-identity > /dev/null 2>&1
check_success "AWS credentials configured"

# Step 2: Verify cluster is active
log_info ""
log_info "Step 2: Verifying cluster status..."
CLUSTER_STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text 2>&1)
if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
    log_info "✓ Cluster is ACTIVE"
else
    log_error "Cluster status: $CLUSTER_STATUS"
    exit 1
fi

# Step 3: Update kubeconfig
log_info ""
log_info "Step 3: Updating kubeconfig..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION --alias eks-$CLUSTER_NAME
check_success "kubeconfig updated"

# Step 4: Install/Update EKS Addons
log_info ""
log_info "Step 4: Installing EKS addons..."

# Check existing addons
EXISTING_ADDONS=$(aws eks list-addons --cluster-name $CLUSTER_NAME --region $REGION --query 'addons[]' --output text)
log_info "Existing addons: $EXISTING_ADDONS"

# Install CoreDNS
if [[ ! "$EXISTING_ADDONS" =~ "coredns" ]]; then
    log_info "Installing coredns..."
    aws eks create-addon \
        --cluster-name $CLUSTER_NAME \
        --addon-name coredns \
        --region $REGION \
        --resolve-conflicts OVERWRITE \
        > /dev/null 2>&1 && log_info "✓ coredns addon created" || log_warn "coredns creation failed or already exists"
else
    log_info "✓ coredns already installed"
fi

# Install kube-proxy
if [[ ! "$EXISTING_ADDONS" =~ "kube-proxy" ]]; then
    log_info "Installing kube-proxy..."
    aws eks create-addon \
        --cluster-name $CLUSTER_NAME \
        --addon-name kube-proxy \
        --region $REGION \
        --resolve-conflicts OVERWRITE \
        > /dev/null 2>&1 && log_info "✓ kube-proxy addon created" || log_warn "kube-proxy creation failed or already exists"
else
    log_info "✓ kube-proxy already installed"
fi

# Install aws-ebs-csi-driver
if [[ ! "$EXISTING_ADDONS" =~ "aws-ebs-csi-driver" ]]; then
    log_info "Installing aws-ebs-csi-driver..."
    aws eks create-addon \
        --cluster-name $CLUSTER_NAME \
        --addon-name aws-ebs-csi-driver \
        --region $REGION \
        --resolve-conflicts OVERWRITE \
        > /dev/null 2>&1 && log_info "✓ aws-ebs-csi-driver addon created" || log_warn "aws-ebs-csi-driver creation failed or already exists"
else
    log_info "✓ aws-ebs-csi-driver already installed"
fi

# Step 5: Wait for addons to become active
log_info ""
log_info "Step 5: Waiting for addons to become active (30 seconds)..."
sleep 30

# Step 6: Test kubectl access
log_info ""
log_info "Step 6: Testing kubectl access..."
if kubectl get svc > /dev/null 2>&1; then
    log_info "✓ kubectl access working!"
    echo ""
    log_info "Cluster nodes:"
    kubectl get nodes -o wide
else
    log_warn "kubectl access still not working"
    log_info "This may require manual intervention. See troubleshooting section below."
fi

# Step 7: Create Kubernetes namespaces
log_info ""
log_info "Step 7: Creating Kubernetes namespaces..."

if kubectl get ns kyverno > /dev/null 2>&1; then
    log_info "✓ kyverno namespace already exists"
else
    if kubectl create namespace kyverno > /dev/null 2>&1; then
        kubectl label namespace kyverno app.kubernetes.io/managed-by=terraform --overwrite
        log_info "✓ kyverno namespace created"
    else
        log_warn "Failed to create kyverno namespace (may require kubectl access fix)"
    fi
fi

if kubectl get ns ml-staging > /dev/null 2>&1; then
    log_info "✓ ml-staging namespace already exists"
else
    if kubectl create namespace ml-staging > /dev/null 2>&1; then
        kubectl label namespace ml-staging environment=staging security-policy=enforced --overwrite
        log_info "✓ ml-staging namespace created"
    else
        log_warn "Failed to create ml-staging namespace (may require kubectl access fix)"
    fi
fi

# Step 8: Verify node groups and nodes
log_info ""
log_info "Step 8: Verifying nodes..."
NODE_GROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --query 'nodegroups[]' --output text)
log_info "Node groups: $NODE_GROUPS"

EC2_COUNT=$(aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=$CLUSTER_NAME" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text \
  --region $REGION | wc -w)
log_info "✓ Running EC2 instances: $EC2_COUNT"

# Step 9: Summary
echo ""
echo "=============================================="
echo "  Infrastructure Setup Status"
echo "=============================================="
echo ""
log_info "Cluster: $CLUSTER_STATUS"
log_info "Node Groups: $(echo $NODE_GROUPS | wc -w)"
log_info "Running Nodes: $EC2_COUNT"
log_info "EKS Addons: $(echo $EXISTING_ADDONS | wc -w)"

# Step 10: Next steps
echo ""
echo "=============================================="
echo "  Next Steps"
echo "=============================================="
echo ""
echo "1. If kubectl access is working:"
echo "   - Kyverno + policies are applied by Terraform (terraform apply)"
echo "   - Deploy application: kubectl apply -f k8s/deployment.yaml"
echo ""
echo "2. If kubectl access is NOT working:"
echo "   - Check CloudWatch logs: /aws/eks/$CLUSTER_NAME/cluster"
echo "   - Verify IAM permissions for your user/role"
echo "   - Try: aws eks update-cluster-config --name $CLUSTER_NAME --region $REGION --access-config authenticationMode=API_AND_CONFIG_MAP"
echo ""
echo "3. Configure GitHub Secrets:"
echo "   - AWS_ACCOUNT_ID: $ACCOUNT_ID"
echo "   - AWS_REGION: $REGION"
echo "   - EKS_CLUSTER_NAME: $CLUSTER_NAME"
echo "   - ECR_REPOSITORY: model-supply-chain-staging/model-server"
echo ""
echo "4. Run the CI/CD pipeline:"
echo "   - Push code to trigger: git push origin main"
echo "   - Or manually trigger via GitHub Actions UI"
echo ""
echo "=============================================="
echo "  Troubleshooting kubectl Access"
echo "=============================================="
echo ""
echo "If kubectl is still not working, try:"
echo ""
echo "A. Check EKS access entries:"
echo "   aws eks list-access-entries --cluster-name $CLUSTER_NAME --region $REGION"
echo ""
echo "B. Describe cluster authentication:"
echo "   aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.accessConfig'"
echo ""
echo "C. Check your IAM identity:"
echo "   aws sts get-caller-identity"
echo ""
echo "D. Manually create access entry (if using API mode):"
echo "   aws eks create-access-entry --cluster-name $CLUSTER_NAME \\"
echo "     --principal-arn arn:aws:iam::$ACCOUNT_ID:root \\"
echo "     --type STANDARD --region $REGION"
echo "   aws eks associate-access-policy --cluster-name $CLUSTER_NAME \\"
echo "     --principal-arn arn:aws:iam::$ACCOUNT_ID:root \\"
echo "     --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \\"
echo "     --access-scope type=cluster --region $REGION"
echo ""
echo "E. Check aws-auth ConfigMap (if using CONFIG_MAP mode):"
echo "   kubectl get configmap aws-auth -n kube-system -o yaml"
echo ""
echo "=============================================="
echo ""
log_info "Script completed!"
