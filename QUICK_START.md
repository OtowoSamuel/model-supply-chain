# 🚀 Quick Start - 5 Minutes to Running Pipeline

## TL;DR - Just Run This

```bash
cd /Users/admin/Documents/Documents/Projects-2026/model-supply-chain

# Make script executable
chmod +x scripts/setup-and-test-full-pipeline.sh

# Run everything
./scripts/setup-and-test-full-pipeline.sh
```

That's it! The script handles everything automatically. ☕ Grab coffee, it takes 20-30 minutes.

---

## What The Script Does

| Step | What Happens | Time |
|------|-------------|------|
| 1 | Check prerequisites (aws, terraform, kubectl, etc.) | 1 min |
| 2 | Deploy AWS infrastructure (EKS cluster + ECR) | 15-20 min |
| 3 | Configure kubectl access to EKS | 1 min |
| 4 | Install Kyverno policy engine | 2 min |
| 5 | Generate Cosign signing keys | 1 min |
| 6 | Configure GitHub secrets | 2 min |
| 7 | Test local pipeline | 3 min |
| 8 | Trigger GitHub Actions pipeline | 15 min |
| 9 | Verify deployment | 2 min |

**Total**: ~40-45 minutes (mostly waiting for AWS)

---

## Before You Start

### Install Tools (One-Time Setup)

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install all required tools
brew install awscli terraform kubectl cosign opa gh
```

### Configure AWS & GitHub

```bash
# AWS credentials
aws configure
# Enter: AWS Access Key ID, Secret Access Key, Region (us-east-1)

# GitHub authentication
gh auth login
# Follow the prompts
```

---

## Manual Quick Start (If Script Fails)

### 1. Deploy Infrastructure (15-20 min)

```bash
cd terraform
terraform init
terraform apply -var="environment=staging" -auto-approve
cd ..
```

### 2. Setup Kubernetes (3 min)

```bash
# Configure kubectl
aws eks update-kubeconfig --name model-supply-chain-staging --region us-east-1

# Install Kyverno
kubectl create -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kyverno -n kyverno --timeout=180s
kubectl apply -f k8s/kyverno-policy.yaml

# Create namespace
kubectl create namespace ml-staging
```

### 3. Generate Keys (1 min)

```bash
mkdir -p keys
COSIGN_PASSWORD="" cosign generate-key-pair --output-key-prefix keys/cosign
kubectl create secret generic cosign-public-key --from-file=cosign.pub=keys/cosign.pub -n ml-staging
```

### 4. GitHub Secrets (2 min)

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "$ACCOUNT_ID" | gh secret set AWS_ACCOUNT_ID
echo "us-east-1" | gh secret set AWS_REGION
echo "model-supply-chain-staging/model-server" | gh secret set ECR_REPOSITORY
echo "model-supply-chain-staging" | gh secret set EKS_CLUSTER_NAME

# Get role ARN
cd terraform
ROLE_ARN=$(terraform output -raw github_role_arn)
echo "$ROLE_ARN" | gh secret set AWS_ROLE_ARN
cd ..
```

**Manual step**: Add `COSIGN_PRIVATE_KEY` and `COSIGN_PASSWORD` via GitHub UI:
- Go to: Settings → Secrets → Actions → New secret
- `COSIGN_PRIVATE_KEY`: Copy entire content of `cat keys/cosign.key`
- `COSIGN_PASSWORD`: The password you entered when generating keys

### 5. Trigger Pipeline (15 min)

```bash
# Create test commit
echo "# Test $(date)" >> .test
git add .test
git commit -m "test: trigger pipeline"
git push origin main

# Watch it run
gh run watch
```

---

## Verify Everything Works

```bash
# 1. Check cluster
kubectl get nodes
# Should show 4 nodes in Ready state

# 2. Check deployment
kubectl get all -n ml-staging
# Should show 2 running pods

# 3. Check ECR images
aws ecr describe-images --repository-name model-supply-chain-staging/model-server --region us-east-1
# Should show at least 1 image

# 4. Test the API
kubectl port-forward -n ml-staging svc/model-server 8080:80 &
curl http://localhost:8080/health
# Should return: {"status": "healthy"}

# 5. Make a prediction
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [5.1, 3.5, 1.4, 0.2]}'
# Should return: {"prediction": 0, "verified": true, ...}
```

---

## Common Issues & Fixes

### "AWS credentials not configured"
```bash
aws configure
# Enter your AWS access key, secret key, and region
```

### "kubectl cannot access cluster"
```bash
./scripts/fix-kubectl-access.sh
```

### "GitHub Actions failing with OIDC error"
```bash
# Verify OIDC provider exists
aws iam list-open-id-connect-providers | grep token.actions.githubusercontent.com

# If missing, re-apply Terraform
cd terraform && terraform apply -var="environment=staging"
```

### "Kyverno blocking deployment"
```bash
# Check policy violations
kubectl describe clusterpolicy verify-model-supply-chain

# View Kyverno logs
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno --tail=100
```

---

## Useful Commands

```bash
# Watch pipeline
gh run watch

# View logs
kubectl logs -n ml-staging -l app=model-server -f

# Check pod status
kubectl get pods -n ml-staging -w

# Describe deployment
kubectl describe deployment model-server -n ml-staging

# View Terraform outputs
cd terraform && terraform output

# Check cluster info
kubectl cluster-info

# View all resources
kubectl get all -A

# Delete everything
./scripts/terraform-destroy-all.sh
```

---

## What You Get

✅ **Kubernetes cluster** (EKS) with 4 nodes  
✅ **Container registry** (ECR) for Docker images  
✅ **Policy enforcement** (Kyverno) blocking unsigned images  
✅ **CI/CD pipeline** (GitHub Actions) fully automated  
✅ **Cryptographic signing** (Cosign) for artifacts  
✅ **Supply chain security** (SLSA Level 3 compliance)  
✅ **Zero-trust deployment** (verify at every stage)  

---

## Cost & Cleanup

**Monthly Cost**: ~$206
- EKS control plane: $73
- EC2 nodes: $90
- NAT Gateway: $33
- Storage/ECR: $10

**To stop charges immediately:**
```bash
./scripts/terraform-destroy-all.sh
```

**To pause (reduce cost to ~$73/month):**
```bash
# Scale down node groups
cd terraform
terraform apply -var="environment=staging" -var="system_node_desired=0" -var="ml_node_desired=0"
```

---

## Next Steps

1. ✅ Verify everything works (see above)
2. 📖 Read the full guide: `cat SETUP_AND_TEST_GUIDE.md`
3. 🎨 Customize for your model: Edit `src/train_model.py`
4. 📊 Add monitoring: Install Prometheus + Grafana
5. 🔔 Setup alerts: Configure Slack notifications
6. 🚀 Deploy to production: Create production namespace

---

## Support

- **Full Guide**: `SETUP_AND_TEST_GUIDE.md`
- **Flow Diagram**: `DEPLOYMENT_FLOW.md`
- **Operations**: `docs/OPERATIONS_RUNBOOK.md`
- **Troubleshooting**: `docs/FAQ.md`

---

**That's it! You now have a production-grade ML supply chain.** 🎉
