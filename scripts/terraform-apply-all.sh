#!/bin/bash
# Complete Terraform Apply Script
# This script deploys all infrastructure in the correct order

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

PROJECT_ROOT="/Users/admin/Documents/Documents/Projects-2026/model-supply-chain"
ENVIRONMENT="${1:-staging}"
REGION="us-east-1"

echo "=============================================="
echo "  Terraform Complete Apply Script"
echo "  Environment: $ENVIRONMENT"
echo "  Region: $REGION"
echo "=============================================="
echo ""

# Check prerequisites
log_step "Checking prerequisites..."
command -v terraform >/dev/null 2>&1 || { log_error "terraform not found"; exit 1; }
command -v aws >/dev/null 2>&1 || { log_error "aws CLI not found"; exit 1; }
aws sts get-caller-identity >/dev/null 2>&1 || { log_error "AWS credentials not configured"; exit 1; }

log_info "✓ Prerequisites met"

# Step 1: Deploy state backend (bootstrap)
echo ""
log_step "Step 1: Deploying Terraform state backend..."
cd "$PROJECT_ROOT/terraform/bootstrap"

if [ ! -d ".terraform" ]; then
    log_info "Initializing bootstrap terraform..."
    terraform init
fi

log_info "Checking if state backend already exists..."
BUCKET_EXISTS=$(aws s3api head-bucket --bucket "tf-state-model-supply-chain-$(aws sts get-caller-identity --query Account --output text)" 2>&1 || echo "NotFound")

if [[ "$BUCKET_EXISTS" == *"NotFound"* ]]; then
    log_info "Creating state backend..."
    terraform apply -auto-approve
    log_info "✓ State backend created"
else
    log_info "✓ State backend already exists"
fi

# Step 2: Deploy main infrastructure
echo ""
log_step "Step 2: Deploying main infrastructure..."
cd "$PROJECT_ROOT/terraform"

if [ ! -d ".terraform" ]; then
    log_info "Initializing main terraform..."
    terraform init
else
    log_info "Reinitializing terraform to ensure backend is configured..."
    terraform init -reconfigure
fi

log_info "Planning infrastructure changes..."
terraform plan -var="environment=$ENVIRONMENT" -out=tfplan

echo ""
read -p "Review the plan above. Continue with apply? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    log_warn "Apply cancelled"
    rm -f tfplan
    exit 0
fi

log_info "Applying infrastructure changes..."
terraform apply tfplan
rm -f tfplan

log_info "✓ Main infrastructure deployed"

# Step 3: Get cluster information
echo ""
log_step "Step 3: Retrieving cluster information..."

CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "model-supply-chain-$ENVIRONMENT")
ECR_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
GITHUB_ROLE=$(terraform output -raw github_actions_role_arn 2>/dev/null || echo "")

log_info "Cluster Name: $CLUSTER_NAME"
log_info "ECR Repository: $ECR_URL"
log_info "GitHub Role: $GITHUB_ROLE"

# Step 4: Configure kubectl
echo ""
log_step "Step 4: Configuring kubectl..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" --alias "eks-$CLUSTER_NAME"

log_info "Testing kubectl access..."
if kubectl get nodes &>/dev/null; then
    log_info "✓ kubectl access working"
    kubectl get nodes -o wide
else
    log_warn "kubectl access not working yet (may need EKS access entry)"
    log_info "Run: ./scripts/fix-kubectl-access.sh"
fi

# Step 5: Wait for node groups
echo ""
log_step "Step 5: Waiting for node groups to be ready..."

for i in {1..30}; do
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$NODE_COUNT" -ge 2 ]; then
        log_info "✓ Found $NODE_COUNT nodes"
        break
    fi
    echo -n "."
    sleep 10
done
echo ""

# Step 6: Verify EKS addons
echo ""
log_step "Step 6: Verifying EKS addons..."
aws eks list-addons --cluster-name "$CLUSTER_NAME" --region "$REGION" --output table

# Step 7: Create namespaces if kubectl is working
echo ""
log_step "Step 7: Creating Kubernetes namespaces..."

if kubectl get nodes &>/dev/null; then
    kubectl create namespace kyverno --dry-run=client -o yaml | kubectl apply -f - || log_warn "kyverno namespace may already exist"
    kubectl label namespace kyverno app.kubernetes.io/managed-by=terraform --overwrite || true
    
    kubectl create namespace ml-staging --dry-run=client -o yaml | kubectl apply -f - || log_warn "ml-staging namespace may already exist"
    kubectl label namespace ml-staging environment=staging security-policy=enforced --overwrite || true
    
    log_info "✓ Namespaces created/updated"
else
    log_warn "Skipping namespace creation (kubectl not accessible)"
fi

# Summary
echo ""
echo "=============================================="
echo "  Deployment Summary"
echo "=============================================="
echo ""
echo "✅ Infrastructure deployed successfully!"
echo ""
echo "Cluster Details:"
echo "  Name:     $CLUSTER_NAME"
echo "  Region:   $REGION"
echo "  Status:   $(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text 2>/dev/null || echo 'Unknown')"
echo "  Nodes:    $(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo 'Unknown') running"
echo ""
echo "Container Registry:"
echo "  ECR URL:  $ECR_URL"
echo ""
echo "GitHub Actions:"
echo "  IAM Role: $GITHUB_ROLE"
echo ""
echo "Terraform State:"
echo "  Backend:  S3 (tf-state-model-supply-chain-*)"
echo "  Locking:  DynamoDB (tf-state-lock-model-supply-chain)"
echo ""
echo "Next Steps:"
echo "  1. Configure GitHub secrets (see docs/GITHUB_ACTIONS_SETUP.md)"
echo "  2. Kyverno + policies already applied by this script (helm_release 1.18.2)"
echo "  3. Test CI/CD pipeline: git push origin main"
echo "  4. Monitor: kubectl get pods -A"
echo ""
echo "Troubleshooting:"
echo "  - kubectl issues: ./scripts/fix-kubectl-access.sh"
echo "  - Complete setup: ./scripts/complete-infrastructure-setup.sh"
echo "  - View outputs: cd terraform && terraform output"
echo ""
log_info "Deployment complete!"
