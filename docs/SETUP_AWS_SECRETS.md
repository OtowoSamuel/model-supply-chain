# AWS Setup Guide - EKS + GitHub Actions

## Prerequisites
- AWS Account
- AWS CLI installed: `brew install awscli`
- Terraform installed: `brew install terraform`

## Step 1: Configure AWS CLI

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your Secret Access Key
# Region: us-east-1
# Output: json
```

## Step 2: Create OIDC Provider for GitHub Actions

```bash
# Create OIDC provider (one-time setup)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

## Step 3: Deploy Infrastructure with Terraform

```bash
# ── STEP 3a: Bootstrap (creates S3 + DynamoDB for state) ──
cd terraform/bootstrap
terraform init
terraform apply
# Note the outputs - bucket name is auto-generated with your account ID

# ── STEP 3b: Deploy EKS ──
cd ../           # back to terraform/
terraform init   # now uses S3 backend
terraform plan -var="environment=staging"
terraform apply -var="environment=staging"

# Get outputs
terraform output
# Save: cluster_name, ecr_repository_url, github_actions_role_arn
```

## Step 4: Add GitHub Secrets

Go to: GitHub repo → Settings → Secrets → Actions

Add these secrets:

```
AWS_ROLE_ARN         = <github_actions_role_arn from terraform output>
AWS_ACCOUNT_ID       = <your AWS account ID>
EKS_CLUSTER_NAME     = model-supply-chain-staging
```

## Step 5: Push to main and run pipeline

```bash
git add .
git commit -m "feat: add AWS EKS + Terraform"
git push origin main
```

The pipeline will:
1. ✅ Train XGBoost fraud detection model
2. ✅ Generate SBOMs
3. ✅ Sign with Cosign
4. ✅ Run OPA policy checks
5. ✅ Build and push to ECR
6. ✅ Sign ECR image
7. ✅ Deploy to EKS (Kyverno verifies signature)

## Infra Pipeline (separate)

Trigger manually:
- GitHub → Actions → "Infrastructure (Terraform + EKS)" → Run workflow

Options:
- `plan` → shows what will change
- `apply` → creates/updates infrastructure
- `destroy` → tears everything down

## Cost Estimate (staging)

| Resource | Cost/month |
|----------|-----------|
| EKS cluster | ~$72 |
| 2x t3.medium (system) | ~$60 |
| 2x t3.xlarge (ML) | ~$120 |
| ECR storage | ~$5 |
| NAT Gateway | ~$32 |
| **Total** | **~$289/month** |

**To minimise costs**: destroy when not in use:
```bash
# Destroy infra
terraform destroy -var="environment=staging"

# Rebuild when needed
terraform apply -var="environment=staging"
```
