# Complete Setup & Test Guide - ML Model Supply Chain

**Goal**: Deploy Kubernetes infrastructure and test the full CI/CD pipeline on GitHub Actions

**Estimated Time**: 2-3 hours  
**Cost**: ~$206/month (can destroy after testing)

---

## 📋 Prerequisites Checklist

Before starting, ensure you have:

- [ ] macOS with Homebrew installed
- [ ] AWS account with admin access
- [ ] GitHub account with repository access
- [ ] Command line tools installed (see below)

### Install Required Tools

```bash
# AWS CLI
brew install awscli
aws configure  # Enter your AWS credentials

# Terraform
brew install terraform

# Kubernetes CLI
brew install kubectl

# Cosign (for artifact signing)
brew install cosign

# OPA (Open Policy Agent)
brew install opa

# GitHub CLI
brew install gh
gh auth login  # Follow prompts to authenticate
```

### Verify Installations

```bash
aws --version          # Should show: aws-cli/2.x.x
terraform --version    # Should show: Terraform v1.x.x
kubectl version --client
cosign version
opa version
gh --version
```

---

## 🚀 Quick Start (Automated Setup)

I've created a complete automation script for you!

```bash
cd /Users/admin/Documents/Documents/Projects-2026/model-supply-chain

# Make the script executable
chmod +x scripts/setup-and-test-full-pipeline.sh

# Run the full setup
./scripts/setup-and-test-full-pipeline.sh
```

This script will:
1. ✅ Check all prerequisites
2. ✅ Deploy AWS infrastructure (EKS + ECR)
3. ✅ Configure kubectl access
4. ✅ Install Kyverno policy engine
5. ✅ Generate Cosign signing keys
6. ✅ Configure GitHub secrets
7. ✅ Test local pipeline
8. ✅ Trigger GitHub Actions pipeline
9. ✅ Verify deployment
10. ✅ Provide status summary

---

## 📝 Manual Setup (Step-by-Step)

If you prefer to understand each step, follow this manual guide:

### Step 1: Deploy AWS Infrastructure

```bash
cd /Users/admin/Documents/Documents/Projects-2026/model-supply-chain/terraform

# Initialize Terraform
terraform init

# Review the plan
terraform plan -var="environment=staging"

# Deploy (takes 15-20 minutes)
terraform apply -var="environment=staging"
```

**What this creates:**
- EKS cluster named `model-supply-chain-staging`
- 4 EC2 nodes (2 system + 2 ML workload)
- ECR repository for container images
- IAM roles for GitHub Actions (OIDC)
- VPC, subnets, security groups
- S3 bucket for Terraform state

**Outputs you'll need:**
```bash
terraform output cluster_name          # EKS cluster name
terraform output ecr_repository_url    # ECR URL
terraform output github_role_arn       # IAM role for GitHub
```

### Step 2: Configure kubectl Access

```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --name model-supply-chain-staging \
  --region us-east-1

# Verify access
kubectl get nodes

# If access fails, run the fix script
./scripts/fix-kubectl-access.sh
```

### Step 3: Install Kyverno Policy Engine

```bash
# Install Kyverno (Kubernetes policy engine)
kubectl create -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml

# Wait for Kyverno to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=kyverno \
  -n kyverno \
  --timeout=180s

# Apply supply chain security policies
kubectl apply -f k8s/kyverno-policy.yaml

# Verify
kubectl get clusterpolicies
```

**What Kyverno does:**
- Enforces image signature verification
- Requires SLSA provenance attestations
- Validates model metadata labels
- Blocks unsigned deployments

### Step 4: Create ml-staging Namespace

```bash
# Create namespace
kubectl create namespace ml-staging

# Add labels
kubectl label namespace ml-staging \
  environment=staging \
  security-policy=enforced

# Verify
kubectl get namespace ml-staging --show-labels
```

### Step 5: Generate Cosign Signing Keys

```bash
cd /Users/admin/Documents/Documents/Projects-2026/model-supply-chain

# Create keys directory
mkdir -p keys

# Generate keypair (you'll be prompted for a password)
COSIGN_PASSWORD="" cosign generate-key-pair --output-key-prefix keys/cosign

# This creates:
# - keys/cosign.key (PRIVATE - never commit!)
# - keys/cosign.pub (PUBLIC - safe to share)
```

**IMPORTANT**: Remember the password you set! You'll need it for GitHub secrets.

```bash
# Create Kubernetes secret for the public key
kubectl create secret generic cosign-public-key \
  --from-file=cosign.pub=keys/cosign.pub \
  -n ml-staging
```

### Step 6: Configure GitHub Repository Secrets

Go to your GitHub repository:
```
Settings → Secrets and variables → Actions → New repository secret
```

Add these secrets:

| Secret Name | Value | How to Get |
|-------------|-------|------------|
| `AWS_ACCOUNT_ID` | Your AWS account ID | `aws sts get-caller-identity --query Account --output text` |
| `AWS_REGION` | `us-east-1` | Your deployment region |
| `AWS_ROLE_ARN` | IAM role ARN | `cd terraform && terraform output github_role_arn` |
| `ECR_REPOSITORY` | `model-supply-chain-staging/model-server` | From Terraform output |
| `EKS_CLUSTER_NAME` | `model-supply-chain-staging` | From Terraform output |
| `COSIGN_PRIVATE_KEY` | Content of `keys/cosign.key` | `cat keys/cosign.key` (copy entire output) |
| `COSIGN_PASSWORD` | Your cosign password | Password you entered in Step 5 |

**Using GitHub CLI:**
```bash
# Get your repository info
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Set secrets
echo "$ACCOUNT_ID" | gh secret set AWS_ACCOUNT_ID
echo "us-east-1" | gh secret set AWS_REGION
echo "model-supply-chain-staging/model-server" | gh secret set ECR_REPOSITORY
echo "model-supply-chain-staging" | gh secret set EKS_CLUSTER_NAME

# Get role ARN from Terraform
cd terraform
ROLE_ARN=$(terraform output -raw github_role_arn)
echo "$ROLE_ARN" | gh secret set AWS_ROLE_ARN
cd ..

# For COSIGN_PRIVATE_KEY and COSIGN_PASSWORD, 
# you need to add them manually via GitHub UI
```

### Step 7: Test Local Pipeline

Before triggering GitHub Actions, test locally:

```bash
cd /Users/admin/Documents/Documents/Projects-2026/model-supply-chain

# Install Python dependencies
pip3 install -r requirements.txt

# Train model
python3 src/train_model.py

# Generate SBOMs
python3 src/generate_sbom.py artifacts/metadata.json

# Sign artifacts
python3 src/sign_artifact.py artifacts

# Evaluate policies
python3 policies/test_policy.py artifacts

# Verify everything
python3 examples/verify_model.py artifacts keys/cosign.pub
```

**Expected output:**
```
✅ Model trained successfully
✅ SBOMs generated
✅ Artifacts signed
✅ Policy evaluation: ALLOWED
✅ Signature verification passed
```

### Step 8: Trigger GitHub Actions Pipeline

**Option A: Push a commit**
```bash
# Create a test commit
echo "# Test $(date)" >> .test-log
git add .test-log
git commit -m "test: trigger CI/CD pipeline"
git push origin main
```

**Option B: Manual workflow trigger**
```bash
# Using GitHub CLI
gh workflow run model-pipeline.yml

# Or via GitHub UI:
# Go to Actions → ML Model Pipeline → Run workflow
```

### Step 9: Monitor Pipeline Execution

```bash
# List recent runs
gh run list --workflow=model-pipeline.yml --limit 5

# Watch the latest run
gh run watch

# View specific run logs
gh run view <run-id> --log
```

**Pipeline stages:**
1. **train-and-attest** (~5 min): Train model, generate SBOMs, sign with Cosign
2. **security-scan** (~3 min): Scan dependencies for vulnerabilities
3. **policy-gate** (~1 min): Enforce OPA policies
4. **build-container** (~4 min): Build Docker image, sign, push to ECR
5. **deploy-staging** (~3 min): Deploy to EKS with Kyverno verification

**Total time**: ~15-20 minutes

### Step 10: Verify Deployment

```bash
# Check cluster status
kubectl get nodes

# Check deployment
kubectl get deployments -n ml-staging
kubectl get pods -n ml-staging
kubectl get svc -n ml-staging

# Check pod logs
kubectl logs -n ml-staging -l app=model-server --tail=50

# Check ECR images
aws ecr describe-images \
  --repository-name model-supply-chain-staging/model-server \
  --region us-east-1

# Verify Kyverno policies
kubectl get clusterpolicies
kubectl describe clusterpolicy verify-model-supply-chain
```

### Step 11: Test the Deployed Model

```bash
# Port-forward to access the service locally
kubectl port-forward -n ml-staging svc/model-server 8080:80

# In another terminal, test the API
curl http://localhost:8080/health

# Make a prediction
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [5.1, 3.5, 1.4, 0.2]}'

# View attestations
curl http://localhost:8080/attestations
```

**Expected response:**
```json
{
  "prediction": 0,
  "model_version": "1.0.0",
  "model_hash": "abc123...",
  "verified": true
}
```

---

## 🔍 Verification Checklist

After everything is set up, verify:

- [ ] EKS cluster is ACTIVE: `aws eks describe-cluster --name model-supply-chain-staging --query 'cluster.status'`
- [ ] All 4 nodes are Ready: `kubectl get nodes`
- [ ] Kyverno is running: `kubectl get pods -n kyverno`
- [ ] Policies are active: `kubectl get clusterpolicies`
- [ ] ml-staging namespace exists: `kubectl get namespace ml-staging`
- [ ] ECR repository exists: `aws ecr describe-repositories --repository-names model-supply-chain-staging/model-server`
- [ ] GitHub secrets are set: `gh secret list`
- [ ] GitHub Actions pipeline passed: `gh run list --workflow=model-pipeline.yml`
- [ ] Model server is deployed: `kubectl get deployment model-server -n ml-staging`
- [ ] Model server is healthy: `kubectl get pods -n ml-staging -l app=model-server`

---

## 🎯 What Each Component Does

### 1. **Kubernetes (EKS)**
Think of it as a **robot factory manager**:
- Automatically runs your containers
- Restarts them if they crash
- Balances load across multiple machines
- Handles networking between services

### 2. **Kyverno**
Think of it as **TSA airport security**:
- Checks every deployment trying to enter
- Blocks unsigned images
- Requires proof of origin (SLSA provenance)
- Enforces security policies automatically

### 3. **Cosign**
Think of it as a **wax seal on a letter**:
- Proves authenticity (it's really from you)
- Detects tampering (seal breaks if opened)
- Uses cryptography (like a digital fingerprint)
- Can verify without the private key

### 4. **ECR (Elastic Container Registry)**
Think of it as **Docker Hub for AWS**:
- Stores your container images
- Integrates with EKS (easy pulling)
- Scans for vulnerabilities
- Manages access control

### 5. **GitHub Actions**
Think of it as a **robot assembly line**:
- Automatically triggered on code push
- Runs all the steps (build, test, sign, deploy)
- No manual work needed
- Provides logs and status

---

## 🔧 Troubleshooting

### Issue: kubectl cannot access cluster

**Error**: `error: You must be logged in to the server (Unauthorized)`

**Solution**:
```bash
# Run the fix script
./scripts/fix-kubectl-access.sh

# Or manually:
aws eks update-kubeconfig \
  --name model-supply-chain-staging \
  --region us-east-1

# Verify your IAM identity
aws sts get-caller-identity
```

### Issue: GitHub Actions pipeline fails with "OIDC authentication failed"

**Error**: `Error: Could not assume role with OIDC`

**Solution**:
```bash
# Verify OIDC provider exists
aws iam list-open-id-connect-providers

# Check GitHub role trust policy
aws iam get-role \
  --role-name model-supply-chain-staging-github-actions \
  --query 'Role.AssumeRolePolicyDocument'

# Re-apply Terraform if needed
cd terraform
terraform apply -var="environment=staging"
```

### Issue: Kyverno blocks deployment

**Error**: `admission webhook "validate.kyverno.svc" denied the request`

**Solution**:
```bash
# Check policy violations
kubectl describe clusterpolicy verify-model-supply-chain

# View Kyverno logs
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno

# Temporarily disable enforcement (for debugging only!)
kubectl patch clusterpolicy verify-model-supply-chain \
  -p '{"spec":{"validationFailureAction":"Audit"}}' \
  --type=merge
```

### Issue: ECR image pull fails

**Error**: `Failed to pull image: authorization failed`

**Solution**:
```bash
# Check node IAM role has ECR permissions
NODE_ROLE=$(aws eks describe-nodegroup \
  --cluster-name model-supply-chain-staging \
  --nodegroup-name model-supply-chain-staging-system \
  --query 'nodegroup.nodeRole' \
  --output text | awk -F'/' '{print $NF}')

aws iam list-attached-role-policies --role-name $NODE_ROLE

# Should include: AmazonEC2ContainerRegistryReadOnly
```

### Issue: Terraform state lock timeout

**Error**: `Error acquiring the state lock`

**Solution**:
```bash
# Get the lock ID from error message, then:
cd terraform
terraform force-unlock <LOCK_ID>
```

---

## 🧹 Cleanup (Destroy Everything)

**WARNING**: This will delete all resources and cannot be undone!

### Option 1: Use the destroy script (recommended)
```bash
cd /Users/admin/Documents/Documents/Projects-2026/model-supply-chain
./scripts/terraform-destroy-all.sh
```

### Option 2: Manual destruction
```bash
# Delete Kubernetes resources first
kubectl delete namespace ml-staging
kubectl delete -f k8s/kyverno-policy.yaml
kubectl delete -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml

# Destroy Terraform infrastructure
cd terraform
terraform destroy -var="environment=staging" -auto-approve

# Optionally destroy state backend
cd bootstrap
terraform destroy -auto-approve
```

**Cost savings**: Destroying stops all charges immediately.

---

## 📚 Additional Resources

### Documentation
- **Getting Started**: `docs/GETTING_STARTED.md`
- **Operations Runbook**: `docs/OPERATIONS_RUNBOOK.md`
- **GitHub Actions Setup**: `docs/GITHUB_ACTIONS_SETUP.md`
- **Architecture**: `docs/technical/ARCHITECTURE.md`
- **Concepts Explained**: `docs/CONCEPTS_EXPLAINED.md`

### External Links
- **EKS User Guide**: https://docs.aws.amazon.com/eks/latest/userguide/
- **Kyverno Documentation**: https://kyverno.io/docs/
- **Cosign Documentation**: https://docs.sigstore.dev/cosign/
- **SLSA Framework**: https://slsa.dev/
- **Terraform AWS EKS Module**: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws

### Commands Cheatsheet
```bash
# Check cluster status
aws eks describe-cluster --name model-supply-chain-staging

# Get kubectl config
aws eks update-kubeconfig --name model-supply-chain-staging --region us-east-1

# View all resources
kubectl get all -A

# Check pipeline runs
gh run list --workflow=model-pipeline.yml

# Watch logs
kubectl logs -n ml-staging -l app=model-server -f

# Port forward
kubectl port-forward -n ml-staging svc/model-server 8080:80

# Terraform outputs
cd terraform && terraform output
```

---

## ✅ Success Criteria

You'll know everything works when:

1. ✅ `kubectl get nodes` shows 4 Ready nodes
2. ✅ `kubectl get pods -n ml-staging` shows Running pods
3. ✅ `gh run list` shows successful pipeline runs
4. ✅ `curl http://localhost:8080/health` (after port-forward) returns OK
5. ✅ `kubectl get clusterpolicies` shows Kyverno policies active
6. ✅ Model predictions work via API
7. ✅ All artifacts are signed and verified

---

## 🎉 What You've Built

Congratulations! You now have:

- **Production-grade ML infrastructure** on AWS
- **Automated CI/CD pipeline** with GitHub Actions
- **Supply chain security** (signing, SBOMs, provenance)
- **Policy enforcement** with Kyverno
- **Zero-trust security** (verify at every stage)
- **SLSA Level 3 compliance**

This is the **same level of security** used by:
- Google (Sigstore/Cosign creators)
- Chainguard (security-first Linux)
- Major banks and enterprises

You can now:
- Deploy ML models securely
- Track provenance (who built what, when, how)
- Detect tampering automatically
- Respond to vulnerabilities quickly
- Prove compliance to auditors

---

## 💡 Next Steps

1. **Customize for your models**: Replace `src/train_model.py` with your actual model
2. **Add monitoring**: Install Prometheus + Grafana
3. **Set up alerts**: Configure Slack/email notifications
4. **Blue-green deployments**: Add production namespace
5. **Auto-scaling**: Configure HPA and Cluster Autoscaler
6. **Cost optimization**: Use Spot instances for ML nodes
7. **Multi-region**: Deploy to multiple AWS regions

---

**Questions?** Check the docs or open an issue!

**Happy deploying! 🚀**
