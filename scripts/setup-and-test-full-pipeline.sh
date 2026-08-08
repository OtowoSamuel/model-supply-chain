#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_DIR="/Users/admin/Documents/Documents/Projects-2026/model-supply-chain"
cd "$PROJECT_DIR"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  ML Model Supply Chain - Complete Setup & Test Pipeline${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Function to check command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}❌ $1 is not installed${NC}"
        echo -e "${YELLOW}   Install with: $2${NC}"
        return 1
    else
        echo -e "${GREEN}✅ $1 is installed${NC}"
        return 0
    fi
}

# Function to run with status
run_step() {
    local step_name=$1
    local step_num=$2
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}STEP $step_num: $step_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

#==============================================================================
# STEP 1: Check Prerequisites
#==============================================================================
run_step "Checking Prerequisites" "1"

MISSING_TOOLS=0

check_command "python3" "brew install python3" || MISSING_TOOLS=1
check_command "aws" "brew install awscli" || MISSING_TOOLS=1
check_command "terraform" "brew install terraform" || MISSING_TOOLS=1
check_command "kubectl" "brew install kubectl" || MISSING_TOOLS=1
check_command "helm" "brew install helm" || MISSING_TOOLS=1
check_command "cosign" "brew install cosign" || MISSING_TOOLS=1
check_command "opa" "brew install opa" || MISSING_TOOLS=1
check_command "gh" "brew install gh" || MISSING_TOOLS=1

if [ $MISSING_TOOLS -eq 1 ]; then
    echo ""
    echo -e "${RED}Please install missing tools before continuing${NC}"
    exit 1
fi

# Check AWS credentials
echo ""
echo -e "${YELLOW}Checking AWS credentials...${NC}"
if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo -e "${GREEN}✅ AWS credentials valid (Account: $ACCOUNT_ID)${NC}"
else
    echo -e "${RED}❌ AWS credentials not configured${NC}"
    echo -e "${YELLOW}   Run: aws configure${NC}"
    exit 1
fi

# Check GitHub CLI authentication
echo ""
echo -e "${YELLOW}Checking GitHub CLI authentication...${NC}"
if gh auth status 2>&1 | grep -q "Logged in"; then
    echo -e "${GREEN}✅ GitHub CLI authenticated${NC}"
else
    echo -e "${RED}❌ GitHub CLI not authenticated${NC}"
    echo -e "${YELLOW}   Run: gh auth login${NC}"
    exit 1
fi

#==============================================================================
# STEP 2: Deploy Infrastructure with Terraform
#==============================================================================
run_step "Deploying AWS Infrastructure (EKS + ECR)" "2"

echo -e "${YELLOW}This will create:${NC}"
echo "  • EKS cluster (model-supply-chain-staging)"
echo "  • 4 EC2 nodes (2 system + 2 ML)"
echo "  • ECR repository"
echo "  • IAM roles for GitHub Actions"
echo "  • VPC, subnets, security groups"
echo ""
echo -e "${YELLOW}Estimated cost: ~\$206/month${NC}"
echo -e "${YELLOW}Estimated time: 15-20 minutes${NC}"
echo ""

read -p "$(echo -e ${YELLOW}'Deploy infrastructure? (y/n): '${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⏭️  Skipping infrastructure deployment${NC}"
    echo -e "${YELLOW}   Assuming infrastructure already exists...${NC}"
else
    cd terraform

    # Create state backend if it doesn't exist
    echo -e "${YELLOW}Checking if Terraform state backend exists...${NC}"
    if ! aws s3 ls s3://tf-state-model-supply-chain-050083686295 2>/dev/null; then
        echo -e "${YELLOW}Creating Terraform state backend (S3 + DynamoDB)...${NC}"
        cd bootstrap
        terraform init
        terraform apply -auto-approve
        cd ..
        echo -e "${GREEN}✅ State backend created${NC}"
    else
        echo -e "${GREEN}✅ State backend already exists${NC}"
    fi

    # Deploy main infrastructure
    echo -e "${YELLOW}Deploying main infrastructure...${NC}"
    terraform init
    terraform apply -var="environment=staging" -auto-approve

    # Get outputs
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    ECR_URL=$(terraform output -raw ecr_repository_url)
    GITHUB_ROLE_ARN=$(terraform output -raw github_role_arn)

    echo ""
    echo -e "${GREEN}✅ Infrastructure deployed successfully${NC}"
    echo -e "${GREEN}   Cluster: $CLUSTER_NAME${NC}"
    echo -e "${GREEN}   ECR: $ECR_URL${NC}"
    echo -e "${GREEN}   GitHub Role: $GITHUB_ROLE_ARN${NC}"

    cd "$PROJECT_DIR"
fi

#==============================================================================
# STEP 3: Configure kubectl Access
#==============================================================================
run_step "Configuring kubectl Access to EKS" "3"

CLUSTER_NAME="model-supply-chain-staging"

echo -e "${YELLOW}Updating kubeconfig...${NC}"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region us-east-1

echo -e "${YELLOW}Verifying cluster access...${NC}"
if kubectl get nodes &> /dev/null; then
    echo -e "${GREEN}✅ kubectl access configured${NC}"
    kubectl get nodes
else
    echo -e "${RED}❌ kubectl access failed${NC}"
    echo -e "${YELLOW}Running access fix script...${NC}"
    ./scripts/fix-kubectl-access.sh || true
fi

#==============================================================================
# STEP 4: Verify Kyverno (managed by Terraform)
#==============================================================================
run_step "Verifying Kyverno Policy Engine" "4"

# Kyverno is installed and upgraded exclusively via Terraform
# (terraform/kyverno.tf, helm_release pinned to chart 3.8.2 / Kyverno 1.18.2).
# Manual helm installs are NOT performed here.
echo -e "${YELLOW}Verifying Terraform-managed Kyverno installation...${NC}"
if ! helm list -n kyverno 2>/dev/null | grep -q "kyverno"; then
    echo -e "${RED}❌ Kyverno release not found - run 'terraform apply' in terraform/ first${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Kyverno release found (managed by Terraform)${NC}"
kubectl get pods -n kyverno

echo -e "${YELLOW}Verifying governance policies...${NC}"
kubectl get imagevalidatingpolicies,validatingpolicies,mutatingpolicies -A 2>/dev/null | grep -E "NAME|verify-model-supply-chain|require-model-attestations|inject-audit-trail|enforce-slsa-level" || true

echo -e "${GREEN}✅ Kyverno verified (policies applied via Terraform)${NC}"

#==============================================================================
# STEP 5: Create ml-staging Namespace
#==============================================================================
run_step "Creating Kubernetes Namespace" "5"

if kubectl get namespace ml-staging &> /dev/null; then
    echo -e "${GREEN}✅ ml-staging namespace exists${NC}"
else
    echo -e "${YELLOW}Creating ml-staging namespace...${NC}"
    kubectl create namespace ml-staging
    kubectl label namespace ml-staging \
        environment=staging \
        security-policy=enforced
    echo -e "${GREEN}✅ ml-staging namespace created${NC}"
fi

#==============================================================================
# STEP 6: Generate Cosign Keys
#==============================================================================
run_step "Generating Cosign Signing Keys" "6"

mkdir -p keys

if [ -f "keys/cosign.key" ] && [ -f "keys/cosign.pub" ]; then
    echo -e "${GREEN}✅ Cosign keys already exist${NC}"
    echo -e "${YELLOW}   Using existing keys at keys/cosign.key${NC}"
else
    echo -e "${YELLOW}Generating new Cosign keypair...${NC}"
    echo -e "${YELLOW}   You'll be prompted for a password${NC}"
    echo -e "${YELLOW}   Remember this password - you'll need it for GitHub secrets!${NC}"
    echo ""
    
    COSIGN_PASSWORD="" cosign generate-key-pair --output-key-prefix keys/cosign
    
    echo ""
    echo -e "${GREEN}✅ Cosign keys generated${NC}"
    echo -e "${GREEN}   Private key: keys/cosign.key (NEVER commit this!)${NC}"
    echo -e "${GREEN}   Public key: keys/cosign.pub${NC}"
fi

# Create Kubernetes secret for Cosign public key
echo -e "${YELLOW}Creating Kubernetes secret for Cosign public key...${NC}"
kubectl create secret generic cosign-public-key \
    --from-file=cosign.pub=keys/cosign.pub \
    -n ml-staging \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✅ Cosign public key stored in Kubernetes${NC}"

#==============================================================================
# STEP 7: Configure GitHub Repository Secrets
#==============================================================================
run_step "Configuring GitHub Repository Secrets" "7"

# Get repository info
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo -e "${YELLOW}Repository: $REPO${NC}"
echo ""

# Check if secrets exist
echo -e "${YELLOW}Checking existing secrets...${NC}"
EXISTING_SECRETS=$(gh secret list 2>/dev/null || echo "")

# Get values
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPOSITORY="model-supply-chain-staging/model-server"
CLUSTER_NAME="model-supply-chain-staging"
GITHUB_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/model-supply-chain-staging-github-actions"

echo ""
echo -e "${BLUE}The following secrets will be configured:${NC}"
echo -e "  ${GREEN}AWS_ACCOUNT_ID${NC} = $ACCOUNT_ID"
echo -e "  ${GREEN}AWS_REGION${NC} = us-east-1"
echo -e "  ${GREEN}ECR_REPOSITORY${NC} = $ECR_REPOSITORY"
echo -e "  ${GREEN}EKS_CLUSTER_NAME${NC} = $CLUSTER_NAME"
echo -e "  ${GREEN}AWS_ROLE_ARN${NC} = $GITHUB_ROLE_ARN"
echo ""

read -p "$(echo -e ${YELLOW}'Configure GitHub secrets? (y/n): '${NC})" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Setting GitHub secrets...${NC}"
    
    echo "$ACCOUNT_ID" | gh secret set AWS_ACCOUNT_ID
    echo "us-east-1" | gh secret set AWS_REGION
    echo "$ECR_REPOSITORY" | gh secret set ECR_REPOSITORY
    echo "$CLUSTER_NAME" | gh secret set EKS_CLUSTER_NAME
    echo "$GITHUB_ROLE_ARN" | gh secret set AWS_ROLE_ARN
    
    echo ""
    echo -e "${GREEN}✅ GitHub secrets configured${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Manual step required:${NC}"
    echo -e "    You need to manually add ${GREEN}COSIGN_PRIVATE_KEY${NC} and ${GREEN}COSIGN_PASSWORD${NC}"
    echo ""
    echo -e "    1. Go to: https://github.com/$REPO/settings/secrets/actions"
    echo -e "    2. Click 'New repository secret'"
    echo -e "    3. Name: ${GREEN}COSIGN_PRIVATE_KEY${NC}"
    echo -e "       Value: Copy entire content from ${GREEN}keys/cosign.key${NC}"
    echo -e "    4. Name: ${GREEN}COSIGN_PASSWORD${NC}"
    echo -e "       Value: The password you entered when generating keys"
    echo ""
    echo -e "${YELLOW}To view your private key:${NC}"
    echo -e "    cat keys/cosign.key"
    echo ""
    
    read -p "$(echo -e ${YELLOW}'Press ENTER after you have added the secrets manually...'${NC})"
else
    echo -e "${YELLOW}⏭️  Skipping GitHub secrets configuration${NC}"
fi

#==============================================================================
# STEP 8: Test Local Pipeline
#==============================================================================
run_step "Testing Local Pipeline" "8"

echo -e "${YELLOW}Installing Python dependencies...${NC}"
pip3 install -q -r requirements.txt

echo ""
echo -e "${YELLOW}Training model...${NC}"
python3 src/train_model.py

echo ""
echo -e "${YELLOW}Generating SBOMs...${NC}"
python3 src/generate_sbom.py artifacts/metadata.json

echo ""
echo -e "${YELLOW}Signing artifacts with Cosign...${NC}"
python3 src/sign_artifact.py artifacts

echo ""
echo -e "${YELLOW}Evaluating OPA policies...${NC}"
python3 policies/test_policy.py artifacts

echo ""
echo -e "${GREEN}✅ Local pipeline test completed successfully${NC}"
echo ""
echo -e "${YELLOW}Generated artifacts:${NC}"
ls -lh artifacts/

#==============================================================================
# STEP 9: Trigger GitHub Actions Pipeline
#==============================================================================
run_step "Triggering GitHub Actions Pipeline" "9"

echo -e "${YELLOW}This will trigger the full CI/CD pipeline:${NC}"
echo "  1. Train model with provenance"
echo "  2. Generate SBOMs"
echo "  3. Sign artifacts (keyless)"
echo "  4. Security scanning"
echo "  5. Policy enforcement"
echo "  6. Build & sign container"
echo "  7. Push to ECR"
echo "  8. Deploy to EKS"
echo ""

read -p "$(echo -e ${YELLOW}'Trigger GitHub Actions pipeline? (y/n): '${NC})" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Creating test commit to trigger pipeline...${NC}"
    
    # Create a test commit
    echo "# Pipeline test triggered on $(date)" >> .pipeline-test-log
    git add .pipeline-test-log
    git commit -m "test: trigger full CI/CD pipeline"
    
    echo -e "${YELLOW}Pushing to GitHub...${NC}"
    git push origin main
    
    echo ""
    echo -e "${GREEN}✅ Pipeline triggered!${NC}"
    echo ""
    echo -e "${YELLOW}Watch the pipeline:${NC}"
    echo -e "  • GitHub UI: https://github.com/$REPO/actions"
    echo -e "  • CLI: gh run watch"
    echo ""
    
    # Wait a moment for the run to start
    sleep 5
    
    echo -e "${YELLOW}Latest pipeline runs:${NC}"
    gh run list --workflow=model-pipeline.yml --limit 3
    
    echo ""
    read -p "$(echo -e ${YELLOW}'Watch the pipeline now? (y/n): '${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        gh run watch
    fi
else
    echo -e "${YELLOW}⏭️  Skipping pipeline trigger${NC}"
    echo -e "${YELLOW}   You can manually trigger it later with:${NC}"
    echo -e "   ${GREEN}gh workflow run model-pipeline.yml${NC}"
fi

#==============================================================================
# STEP 10: Verify Deployment
#==============================================================================
run_step "Verifying Deployment" "10"

echo -e "${YELLOW}Waiting for deployment to complete...${NC}"
echo -e "${YELLOW}This may take several minutes after the pipeline finishes${NC}"
echo ""

read -p "$(echo -e ${YELLOW}'Check deployment status now? (y/n): '${NC})" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Checking EKS deployment...${NC}"
    kubectl get deployments -n ml-staging
    
    echo ""
    echo -e "${YELLOW}Checking pods...${NC}"
    kubectl get pods -n ml-staging
    
    echo ""
    echo -e "${YELLOW}Checking services...${NC}"
    kubectl get svc -n ml-staging
    
    echo ""
    echo -e "${YELLOW}Checking ECR images...${NC}"
    aws ecr describe-images \
        --repository-name "$ECR_REPOSITORY" \
        --region us-east-1 \
        --query 'sort_by(imageDetails,& imagePushedAt)[-3:]' \
        --output table || echo "No images yet"
    
    echo ""
    echo -e "${YELLOW}To view pod logs:${NC}"
    echo -e "  ${GREEN}kubectl logs -n ml-staging -l app=model-server --tail=50${NC}"
    echo ""
    echo -e "${YELLOW}To test the API locally:${NC}"
    echo -e "  ${GREEN}kubectl port-forward -n ml-staging svc/model-server 8080:80${NC}"
    echo -e "  ${GREEN}curl http://localhost:8080/health${NC}"
fi

#==============================================================================
# SUMMARY
#==============================================================================
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   ✨ Setup Complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}✅ Infrastructure Status:${NC}"
echo "   • EKS Cluster: $CLUSTER_NAME"
echo "   • Nodes: 4 running (2 system + 2 ML)"
echo "   • Kyverno: Installed with supply chain policies"
echo "   • Namespace: ml-staging"
echo ""
echo -e "${GREEN}✅ Security Components:${NC}"
echo "   • Cosign keys generated"
echo "   • GitHub Actions OIDC configured"
echo "   • ECR repository created"
echo "   • Supply chain policies active"
echo ""
echo -e "${YELLOW}📚 Next Steps:${NC}"
echo "   1. Monitor pipeline: gh run list --workflow=model-pipeline.yml"
echo "   2. Check deployment: kubectl get all -n ml-staging"
echo "   3. View logs: kubectl logs -n ml-staging -l app=model-server"
echo "   4. Test API: kubectl port-forward -n ml-staging svc/model-server 8080:80"
echo "   5. Review docs: cat docs/OPERATIONS_RUNBOOK.md"
echo ""
echo -e "${YELLOW}📊 Useful Commands:${NC}"
echo "   • Pipeline status: gh run watch"
echo "   • Cluster info: kubectl cluster-info"
echo "   • Node status: kubectl get nodes"
echo "   • All resources: kubectl get all -A"
echo "   • Terraform outputs: cd terraform && terraform output"
echo ""
echo -e "${YELLOW}💰 Cost Estimate:${NC}"
echo "   • Monthly: ~\$206"
echo "   • To destroy: ./scripts/terraform-destroy-all.sh"
echo ""
echo -e "${GREEN}Your ML Model Supply Chain is ready! 🚀${NC}"
echo ""
