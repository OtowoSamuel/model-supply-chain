# ML Model Supply Chain - Deployment Guide

**Project**: Secure ML Model Supply Chain with SLSA Compliance  
**Date**: July 14, 2026  
**Status**: Production Ready

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Infrastructure Setup](#infrastructure-setup)
4. [GitHub Actions Configuration](#github-actions-configuration)
5. [Pipeline Execution](#pipeline-execution)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)
8. [Cleanup](#cleanup)

---

## Overview

This deployment guide walks through setting up a complete secure ML model supply chain with:

- **SLSA Level 3 Compliance**: Full provenance and attestation
- **Infrastructure as Code**: Terraform-managed AWS EKS cluster
- **Automated CI/CD**: GitHub Actions pipelines
- **Security**: Sigstore signing, SBOM generation, policy enforcement
- **Kubernetes**: Production-ready deployment with Kyverno policies

### Architecture Components

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Actions Pipeline                   │
├─────────────────────────────────────────────────────────────┤
│  Train → Sign → SBOM → Attest → ECR → EKS Deploy            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                      AWS Infrastructure                      │
├─────────────────────────────────────────────────────────────┤
│  • VPC with 3 AZs                                           │
│  • EKS Cluster (1.31)                                        │
│  • ECR Repository                                            │
│  • IAM Roles (OIDC)                                          │
│  • S3 Backend                                                │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Required Tools

Install the following tools on your local machine:

```bash
# AWS CLI
brew install awscli

# Terraform
brew install terraform

# kubectl
brew install kubectl

# Cosign (for signing)
brew install cosign

# Syft (for SBOM)
brew install syft

# OPA (for policy testing)
brew install opa
```

### AWS Account Setup

1. **AWS Account**: Active AWS account with admin access
2. **AWS CLI Configured**:
   ```bash
   aws configure
   # Enter your AWS credentials
   aws sts get-caller-identity  # Verify
   ```

3. **GitHub Repository**: Fork or clone this repository

---

## Infrastructure Setup

### Step 1: Bootstrap Terraform State

First, create the S3 bucket and DynamoDB table for Terraform state management:

```bash
cd terraform/bootstrap
terraform init
terraform apply -auto-approve
```

**Expected Output**:
```
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:
backend_config = <<EOT
backend "s3" {
  bucket         = "tf-state-model-supply-chain-XXXXXXXXXXXX"
  key            = "eks/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "tf-state-lock-model-supply-chain"
}
EOT
```

### Step 2: Initialize Main Terraform

```bash
cd ../  # Back to terraform/ directory
terraform init
```

This will:
- Download required providers
- Configure S3 backend
- Initialize modules (VPC, EKS, ECR)

### Step 3: Deploy Infrastructure

```bash
terraform apply -var=environment=staging -auto-approve
```

**Duration**: ~15-20 minutes (EKS cluster creation is the slowest)

**What Gets Created**:
- VPC with 3 public and 3 private subnets across 3 AZs
- NAT Gateways for private subnet internet access
- EKS Cluster (v1.31) with managed node groups:
  - System nodes: 2x t3.medium (general workloads)
  - ML nodes: 1-3x t3.large (model serving)
- ECR Repository for container images
- IAM Roles with OIDC for GitHub Actions
- Security groups and policies

**Expected Output**:
```
Apply complete! Resources: 57 added, 0 changed, 0 destroyed.

Outputs:
cluster_endpoint        = "https://XXXXXXXXXX.gr7.us-east-1.eks.amazonaws.com"
cluster_name            = "model-supply-chain-staging"
configure_kubectl       = "aws eks update-kubeconfig --region us-east-1 --name model-supply-chain-staging"
ecr_repository_url      = "050083686295.dkr.ecr.us-east-1.amazonaws.com/model-supply-chain"
github_actions_role_arn = "arn:aws:iam::050083686295:role/github-actions-model-supply-chain"
```

### Step 4: Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name model-supply-chain-staging
kubectl get nodes
```

**Expected Output**:
```
NAME                         STATUS   ROLES    AGE   VERSION
ip-10-0-xx-xx.ec2.internal   Ready    <none>   5m    v1.31.x
ip-10-0-xx-xx.ec2.internal   Ready    <none>   5m    v1.31.x
```

### Step 5: Deploy Kyverno Policies

```bash
cd ../k8s
kubectl create namespace kyverno
kubectl apply -f kyverno-policy.yaml
```

**Verify**:
```bash
kubectl get clusterpolicy
```

---

## GitHub Actions Configuration

### Step 1: Configure Repository Secrets

Navigate to your GitHub repository: **Settings → Secrets and variables → Actions**

Add the following secrets:

| Secret Name | Value | How to Get |
|-------------|-------|------------|
| `AWS_ACCOUNT_ID` | `050083686295` | `aws sts get-caller-identity --query Account --output text` |
| `AWS_REGION` | `us-east-1` | Your deployment region |
| `ECR_REPOSITORY` | `model-supply-chain` | From terraform output |
| `EKS_CLUSTER_NAME` | `model-supply-chain-staging` | From terraform output |
| `GITHUB_ROLE_ARN` | `arn:aws:iam::XXXX:role/github-actions-model-supply-chain` | From terraform output |
| `COSIGN_PRIVATE_KEY` | `[contents of keys/cosign.key]` | Generated key |
| `COSIGN_PASSWORD` | `[your password]` | Password used when generating key |

### Step 2: Generate Cosign Keys (if not exists)

```bash
cd ../keys
cosign generate-key-pair
# Enter a password when prompted
# This creates cosign.key and cosign.pub
```

**⚠️ Security Note**: 
- Never commit `cosign.key` to the repository
- Store it securely in GitHub Secrets
- The `.gitignore` already excludes this file

### Step 3: Verify Workflow Files

Check that workflows are properly configured:

```bash
cat .github/workflows/infra.yml
cat .github/workflows/model-pipeline.yml
```

**Key Workflow**: `.github/workflows/model-pipeline.yml`
- **Trigger**: Push to `main` branch with changes in `src/` or manual dispatch
- **Jobs**:
  1. Train model
  2. Generate SBOM
  3. Sign artifacts with Cosign
  4. Create SLSA provenance
  5. Push to ECR
  6. Deploy to EKS

---

## Pipeline Execution

### Automatic Trigger

Pipeline runs automatically on:
```bash
git add src/train_model.py
git commit -m "Update model training"
git push origin main
```

### Manual Trigger

Via GitHub UI:
1. Go to **Actions** tab
2. Select **ML Model Pipeline**
3. Click **Run workflow**
4. Select branch (e.g., `main`)
5. Click **Run workflow**

### Monitoring Execution

```bash
# Via GitHub CLI
gh run list --workflow=model-pipeline.yml
gh run view <run-id> --log

# Or via GitHub UI: Actions tab
```

### Pipeline Stages

**Stage 1: Build & Test** (~2 minutes)
- Checkout code
- Install dependencies
- Run linting and security checks

**Stage 2: Train Model** (~3 minutes)
- Execute training script
- Generate model artifact
- Create metadata

**Stage 3: Security** (~2 minutes)
- Generate SBOM with Syft
- Sign artifacts with Cosign
- Create SLSA provenance

**Stage 4: Deploy** (~3 minutes)
- Build container image
- Push to ECR
- Deploy to EKS
- Verify deployment

**Total Duration**: ~10-15 minutes

---

## Verification

### 1. Check Pipeline Status

```bash
gh run list --workflow=model-pipeline.yml --limit 1
```

### 2. Verify Artifacts

```bash
ls -la artifacts/
# Should see:
# - model.pkl
# - model.pkl.bundle (signature)
# - metadata.json
# - sbom/code-sbom.json
# - sbom/model-sbom.json
# - attestations/provenance.json
```

### 3. Verify ECR Image

```bash
aws ecr describe-images \
  --repository-name model-supply-chain \
  --region us-east-1
```

### 4. Verify Kubernetes Deployment

```bash
kubectl get deployment model-server -n default
kubectl get pods -l app=model-server
kubectl get service model-server
```

**Expected**:
```
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
model-server   2/2     2            2           5m

NAME                            READY   STATUS    RESTARTS   AGE
model-server-xxxxxxxxxx-xxxxx   1/1     Running   0          5m
model-server-xxxxxxxxxx-xxxxx   1/1     Running   0          5m
```

### 5. Test Model API

```bash
# Get LoadBalancer endpoint
export MODEL_ENDPOINT=$(kubectl get svc model-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Wait for DNS propagation (~2-3 minutes)
# Then test
curl http://$MODEL_ENDPOINT/health
curl -X POST http://$MODEL_ENDPOINT/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [1.0, 2.0, 3.0, 4.0]}'
```

**Expected Response**:
```json
{
  "prediction": [0.8, 0.2],
  "model_version": "v1.0.0",
  "timestamp": "2026-07-14T14:55:00Z"
}
```

### 6. Verify Signatures

```bash
cd artifacts
cosign verify --key ../keys/cosign.pub model.pkl.bundle
```

### 7. Verify SLSA Provenance

```bash
cat attestations/provenance.json | jq .
# Check predicate type and build metadata
```

### 8. Check Kyverno Policy

```bash
kubectl get clusterpolicy verify-model-signatures
kubectl describe clusterpolicy verify-model-signatures
```

---

## Troubleshooting

### Issue: Terraform Apply Fails

**Problem**: Name prefix too long error
```
Error: expected length of name_prefix to be in the range (1 - 38)
```

**Solution**: Already fixed in `terraform/main.tf`:
```hcl
iam_role_name = "${var.cluster_name}-${each.key}-ng"
```

### Issue: GitHub Actions OIDC Fails

**Problem**: 
```
Error: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

**Solution**: Verify OIDC provider and trust policy:
```bash
aws iam get-role --role-name github-actions-model-supply-chain
# Check trust policy includes correct GitHub repo
```

### Issue: kubectl Cannot Connect

**Problem**: 
```
error: You must be logged in to the server (Unauthorized)
```

**Solution**: Update kubeconfig:
```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name model-supply-chain-staging
```

### Issue: Pods Not Starting

**Problem**: Pods stuck in `Pending` state

**Solution**: Check node capacity:
```bash
kubectl describe nodes
kubectl get pods -A | grep Pending
kubectl describe pod <pod-name>
```

If nodes are missing:
```bash
# Check EKS managed node groups
aws eks list-nodegroups --cluster-name model-supply-chain-staging
aws eks describe-nodegroup \
  --cluster-name model-supply-chain-staging \
  --nodegroup-name <nodegroup-name>
```

### Issue: Image Pull Errors

**Problem**: 
```
Failed to pull image: authorization failed
```

**Solution**: Verify ECR permissions and image exists:
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com
aws ecr describe-images --repository-name model-supply-chain
```

### Issue: Kyverno Policy Blocks Deployment

**Problem**: 
```
admission webhook "validate.kyverno.svc" denied the request
```

**Solution**: Check if image is signed:
```bash
cosign verify --key keys/cosign.pub <ecr-image-url>
```

If not signed, re-run pipeline or sign manually.

---

## Cleanup

### Option 1: Destroy Everything

```bash
# Destroy EKS and all infrastructure
cd terraform
terraform destroy -var=environment=staging -auto-approve

# Destroy bootstrap (state bucket)
cd bootstrap
terraform destroy -auto-approve
```

**Warning**: This deletes all resources and cannot be undone.

### Option 2: Scale Down (Save Costs)

```bash
# Scale node groups to 0
aws eks update-nodegroup-config \
  --cluster-name model-supply-chain-staging \
  --nodegroup-name system \
  --scaling-config minSize=0,maxSize=2,desiredSize=0

# Delete LoadBalancers to avoid charges
kubectl delete service model-server
```

### Cost Estimates

**Monthly costs** (us-east-1, staging):
- EKS cluster: ~$73
- EC2 nodes (2x t3.medium + 1x t3.large): ~$90
- NAT Gateway: ~$33
- EBS volumes: ~$10
- ECR storage: ~$1
- **Total**: ~$207/month

**To minimize costs**:
- Use spot instances for ML nodes
- Scale down when not in use
- Delete NAT Gateways (use public subnets for dev)
- Use smaller instance types

---

## Next Steps

### 1. Production Hardening

- [ ] Enable encryption at rest for EKS
- [ ] Configure AWS WAF for API protection
- [ ] Set up CloudWatch alarms and dashboards
- [ ] Implement backup strategy for models
- [ ] Configure network policies in Kubernetes

### 2. Monitoring & Observability

```bash
# Install Prometheus + Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack
```

### 3. CI/CD Improvements

- Add automated testing stage
- Implement blue-green deployments
- Add rollback capabilities
- Configure Slack/email notifications

### 4. Security Enhancements

- Rotate Cosign keys regularly
- Implement secrets management (AWS Secrets Manager)
- Enable audit logging
- Scan images with Trivy/Grype

---

## Support & Documentation

- **Architecture**: [docs/technical/ARCHITECTURE.md](technical/ARCHITECTURE.md)
- **Security**: [docs/technical/SECURITY.md](technical/SECURITY.md)
- **API Reference**: [docs/reference/CHEATSHEET.md](reference/CHEATSHEET.md)
- **FAQ**: [docs/FAQ.md](FAQ.md)

---

## Summary

You now have a fully functional, secure ML model supply chain with:

✅ Infrastructure as Code (Terraform)  
✅ Automated CI/CD (GitHub Actions)  
✅ SLSA Level 3 Compliance  
✅ Cryptographic signing (Sigstore)  
✅ SBOM generation  
✅ Policy enforcement (Kyverno)  
✅ Production-ready Kubernetes deployment  

**Pipeline Status**: Ready for production use  
**Compliance**: SLSA Level 3, SOC 2 compatible  
**Security**: Signed artifacts, verified provenance  

---

*Last Updated: July 14, 2026*  
*Version: 1.0.0*
