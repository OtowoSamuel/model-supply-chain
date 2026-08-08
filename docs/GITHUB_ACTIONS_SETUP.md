# GitHub Actions CI/CD Setup Guide

Complete guide to configuring GitHub Actions for the ML Model Supply Chain pipeline.

---

## Prerequisites

- ✅ EKS cluster deployed and active
- ✅ ECR repository created
- ✅ IAM role for GitHub Actions created
- ✅ Node groups running
- Cosign keys generated

---

## Step 1: Generate Cosign Keys (if not done)

```bash
cd /Users/admin/Documents/Documents/Projects-2026/model-supply-chain/keys

# Generate key pair
cosign generate-key-pair

# Enter a password when prompted
# This creates:
# - cosign.key (private key - NEVER commit)
# - cosign.pub (public key - safe to commit)
```

**Security Note**: The `cosign.key` file is already in `.gitignore` and should NEVER be committed to the repository.

---

## Step 2: Configure GitHub Repository Secrets

Navigate to your GitHub repository:
```
Settings → Secrets and variables → Actions → New repository secret
```

### Required Secrets

| Secret Name | Value | How to Get |
|-------------|-------|------------|
| `AWS_ACCOUNT_ID` | `050083686295` | Already known |
| `AWS_REGION` | `us-east-1` | Your deployment region |
| `ECR_REPOSITORY` | `model-supply-chain-staging/model-server` | From terraform output |
| `EKS_CLUSTER_NAME` | `model-supply-chain-staging` | From terraform output |
| `GITHUB_ROLE_ARN` | `arn:aws:iam::050083686295:role/model-supply-chain-staging-github-actions` | From terraform output |
| `COSIGN_PRIVATE_KEY` | `[contents of keys/cosign.key]` | See below |
| `COSIGN_PASSWORD` | `[your password]` | Password you entered when generating keys |

### How to Get Cosign Private Key Content

```bash
# Display the private key content
cat /Users/admin/Documents/Documents/Projects-2026/model-supply-chain/keys/cosign.key

# Copy the ENTIRE output including:
# -----BEGIN ENCRYPTED COSIGN PRIVATE KEY-----
# ... key content ...
# -----END ENCRYPTED COSIGN PRIVATE KEY-----
```

Then paste this entire content into the `COSIGN_PRIVATE_KEY` secret in GitHub.

---

## Step 3: Verify GitHub OIDC Configuration

The terraform already configured OIDC for GitHub Actions. Verify it exists:

```bash
aws iam list-open-id-connect-providers | grep token.actions.githubusercontent.com
```

Expected output:
```
"Arn": "arn:aws:iam::050083686295:oidc-provider/token.actions.githubusercontent.com"
```

---

## Step 4: Update Workflow Files (if needed)

The workflows are already configured, but verify these settings:

### `.github/workflows/model-pipeline.yml`

Key sections to verify:

```yaml
env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: model-supply-chain-staging/model-server
  EKS_CLUSTER_NAME: model-supply-chain-staging

permissions:
  id-token: write  # Required for AWS OIDC
  contents: read
```

### `.github/workflows/infra.yml`

Infrastructure deployment workflow (if using):

```yaml
env:
  AWS_REGION: us-east-1
  TERRAFORM_VERSION: 1.5.0
```

---

## Step 5: Test the Pipeline

### Option A: Manual Trigger

1. Go to GitHub Actions tab
2. Select "ML Model Pipeline" workflow
3. Click "Run workflow"
4. Select branch (main)
5. Click "Run workflow"

### Option B: Automatic Trigger

```bash
# Make a change to trigger the pipeline
cd /Users/admin/Documents/Documents/Projects-2026/model-supply-chain

# Update a file
echo "# Test change" >> README.md

# Commit and push
git add README.md
git commit -m "test: trigger CI/CD pipeline"
git push origin main
```

---

## Step 6: Monitor Pipeline Execution

### Via GitHub UI

1. Navigate to **Actions** tab in GitHub
2. Click on the running workflow
3. Monitor each job:
   - Setup
   - Build & Test
   - Train Model
   - Security Scanning
   - Sign Artifacts
   - Push to ECR
   - Deploy to EKS

### Via GitHub CLI

```bash
# Install GitHub CLI if not installed
brew install gh

# Authenticate
gh auth login

# List recent runs
gh run list --workflow=model-pipeline.yml --limit 5

# Watch a specific run
gh run watch <run-id>

# View logs
gh run view <run-id> --log
```

---

## Step 7: Verify Deployment

After the pipeline completes successfully:

```bash
# Check ECR for pushed images
aws ecr describe-images \
  --repository-name model-supply-chain-staging/model-server \
  --region us-east-1

# Check EKS deployment
kubectl get deployments -n ml-staging
kubectl get pods -n ml-staging
kubectl get svc -n ml-staging

# Check pod logs
kubectl logs -n ml-staging -l app=model-server --tail=50

# Test the API
kubectl port-forward -n ml-staging svc/model-server 8080:80
curl http://localhost:8080/health
```

---

## Pipeline Stages Explained

### Stage 1: Setup & Checkout
- Checks out code
- Configures AWS credentials using OIDC
- Sets up Python environment

### Stage 2: Build & Dependencies
- Installs Python dependencies
- Runs linting (flake8, pylint)
- Runs security scanning (bandit)

### Stage 3: Model Training
- Executes `src/train_model.py`
- Generates model artifact (`artifacts/model.pkl`)
- Creates metadata file

### Stage 4: SBOM Generation
- Generates Software Bill of Materials
- Creates `artifacts/sbom/code-sbom.json`
- Creates `artifacts/sbom/model-sbom.json`

### Stage 5: Artifact Signing
- Signs model artifact with Cosign
- Creates signature bundle (`artifacts/model.pkl.bundle`)
- Signs SBOM files

### Stage 6: SLSA Provenance
- Generates SLSA Level 3 provenance
- Records build metadata
- Creates `artifacts/attestations/provenance.json`

### Stage 7: Container Build & Push
- Builds Docker image with model
- Tags image with git SHA and latest
- Pushes to ECR
- Signs container image

### Stage 8: Deploy to EKS
- Updates deployment manifest
- Applies to Kubernetes cluster
- Waits for rollout completion
- Verifies deployment health

---

## Troubleshooting

### Issue: "Error: OIDC authentication failed"

**Cause**: GitHub OIDC provider not configured or role trust policy incorrect

**Solution**:
```bash
# Verify OIDC provider exists
aws iam list-open-id-connect-providers

# Check role trust policy
aws iam get-role --role-name model-supply-chain-staging-github-actions \
  --query 'Role.AssumeRolePolicyDocument'

# Should include:
# "Principal": {
#   "Federated": "arn:aws:iam::050083686295:oidc-provider/token.actions.githubusercontent.com"
# }
```

### Issue: "Error: ECR authentication failed"

**Cause**: IAM role doesn't have ECR permissions

**Solution**:
```bash
# Verify role has ECR permissions
aws iam list-attached-role-policies \
  --role-name model-supply-chain-staging-github-actions

# Should include:
# - AmazonEC2ContainerRegistryPowerUser (or custom policy with ecr:*)
```

### Issue: "Error: kubectl not authorized"

**Cause**: IAM role doesn't have EKS access

**Solution**:
```bash
# Add EKS access entry for GitHub Actions role
aws eks create-access-entry \
  --cluster-name model-supply-chain-staging \
  --principal-arn arn:aws:iam::050083686295:role/model-supply-chain-staging-github-actions \
  --type STANDARD \
  --region us-east-1

# Associate admin policy
aws eks associate-access-policy \
  --cluster-name model-supply-chain-staging \
  --principal-arn arn:aws:iam::050083686295:role/model-supply-chain-staging-github-actions \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region us-east-1
```

### Issue: "Error: Cosign signature verification failed"

**Cause**: Wrong public key or password

**Solution**:
```bash
# Verify the public key matches private key
cosign public-key --key keys/cosign.key

# Make sure GitHub secret COSIGN_PASSWORD matches the password used during key generation
```

### Issue: "Error: Image pull failed in Kubernetes"

**Cause**: Kubernetes can't pull from ECR

**Solution**:
```bash
# Verify node IAM role has ECR pull permissions
NODE_ROLE_NAME=$(aws eks describe-nodegroup \
  --cluster-name model-supply-chain-staging \
  --nodegroup-name model-supply-chain-staging-system \
  --query 'nodegroup.nodeRole' \
  --output text | awk -F'/' '{print $NF}')

aws iam list-attached-role-policies --role-name $NODE_ROLE_NAME

# Should include:
# - AmazonEC2ContainerRegistryReadOnly
```

---

## Pipeline Security Features

### SLSA Level 3 Compliance
- ✅ Provenance generation
- ✅ Non-falsifiable provenance
- ✅ Build platform guarantees
- ✅ Artifact signing with Cosign

### Software Bill of Materials (SBOM)
- ✅ Code dependencies tracked
- ✅ Model artifacts cataloged
- ✅ Container layers documented

### Supply Chain Security
- ✅ Cryptographic signing (Sigstore/Cosign)
- ✅ Signature verification in deployment
- ✅ Policy enforcement (Kyverno)

### Access Control
- ✅ OIDC authentication (no long-lived credentials)
- ✅ Least privilege IAM roles
- ✅ EKS access entries

---

## Performance Optimization

### Speed Up Pipeline

1. **Cache Dependencies**:
   Already configured in workflow:
   ```yaml
   - uses: actions/cache@v3
     with:
       path: ~/.cache/pip
       key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}
   ```

2. **Parallel Jobs**:
   Consider splitting into parallel jobs:
   - Linting & security scanning
   - Model training
   - SBOM generation

3. **Use Self-Hosted Runners** (optional):
   For faster builds, especially for ML training:
   ```yaml
   runs-on: [self-hosted, ml-training]
   ```

---

## Cost Optimization

### GitHub Actions Minutes

- Free tier: 2,000 minutes/month for private repos
- Current pipeline: ~10-15 minutes per run
- Estimated runs: ~130/month within free tier

### AWS Costs

- ECR storage: ~$0.10/GB/month
- Data transfer: First 1GB free, then $0.09/GB
- EKS API calls: Negligible

**Tip**: Delete old ECR images using lifecycle policies (already configured).

---

## Next Steps

1. ✅ Configure all GitHub secrets
2. ✅ Test pipeline with manual trigger
3. ✅ Verify artifacts are signed
4. ✅ Check deployment in EKS
5. Configure Slack/email notifications (optional)
6. Set up automated testing
7. Implement blue-green deployments

---

## Additional Resources

- **Cosign Documentation**: https://docs.sigstore.dev/cosign/overview/
- **SLSA Framework**: https://slsa.dev/
- **GitHub OIDC**: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
- **EKS Best Practices**: https://aws.github.io/aws-eks-best-practices/

---

*Last Updated: July 14, 2026*
