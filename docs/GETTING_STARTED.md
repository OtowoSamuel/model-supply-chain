# Getting Started with ML Model Supply Chain

Quick start guide to use your newly deployed infrastructure.

---

## 🎯 You Are Here

Your ML Model Supply Chain infrastructure is **70% deployed** and ready for the final configuration steps.

**Status**: Staging environment operational, pending kubectl access and CI/CD secrets.

---

## ⚡ Quick Start (5 Minutes)

### Step 1: Fix kubectl Access
```bash
cd /Users/admin/Documents/Documents/Projects-2026/model-supply-chain
./scripts/fix-kubectl-access.sh
```

### Step 2: Complete Infrastructure Setup
```bash
./scripts/complete-infrastructure-setup.sh
```

### Step 3: Configure GitHub Secrets
Follow the guide: [docs/GITHUB_ACTIONS_SETUP.md](docs/GITHUB_ACTIONS_SETUP.md)

### Step 4: Test the Pipeline
```bash
# Push a commit to trigger the pipeline
git add .
git commit -m "test: trigger pipeline"
git push origin main
```

---

## 📚 Documentation Map

### New to the Project?
Start here: [EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md)

### Need to Deploy?
Follow this: [docs/DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md)

### Daily Operations?
Use this: [docs/OPERATIONS_RUNBOOK.md](docs/OPERATIONS_RUNBOOK.md)

### CI/CD Setup?
Read this: [docs/GITHUB_ACTIONS_SETUP.md](docs/GITHUB_ACTIONS_SETUP.md)

### What's the Status?
Check here: [INFRASTRUCTURE_STATUS.md](INFRASTRUCTURE_STATUS.md)

### Technical Details?
See this: [docs/technical/ARCHITECTURE.md](docs/technical/ARCHITECTURE.md)

---

## 🔧 Common Tasks

### Check Cluster Status
```bash
aws eks describe-cluster --name model-supply-chain-staging --region us-east-1 --query 'cluster.status'
```

### List Nodes
```bash
kubectl get nodes -o wide
```

### View Deployments
```bash
kubectl get deployments -A
```

### Check Pipeline Runs
```bash
gh run list --workflow=model-pipeline.yml --limit 5
```

### View Terraform State
```bash
cd terraform
terraform show
```

---

## 🆘 Troubleshooting

### kubectl Not Working?
Run: `./scripts/fix-kubectl-access.sh`

### Pipeline Failing?
Check: [docs/GITHUB_ACTIONS_SETUP.md](docs/GITHUB_ACTIONS_SETUP.md)

### AWS Permission Issues?
Verify: `aws sts get-caller-identity`

### Need Help?
Read: [FINAL_DEPLOYMENT_REPORT.md](FINAL_DEPLOYMENT_REPORT.md)

---

## 📊 Infrastructure Overview

- **Cluster**: model-supply-chain-staging (EKS 1.30)
- **Nodes**: 4 running (2 system + 2 ML)
- **Region**: us-east-1
- **Cost**: ~$216/month (staging)
- **Security**: SLSA Level 3 compliant

---

## ✅ What's Working

✅ EKS cluster (ACTIVE)  
✅ Node groups (4 instances running)  
✅ ECR repository  
✅ IAM roles and policies  
✅ Terraform state backend  
✅ OIDC for GitHub Actions  
✅ Artifact signing setup  
✅ Comprehensive documentation  

---

## ⚠️ What Needs Attention

⚠️ kubectl authentication (1-2 hours to fix)  
⚠️ GitHub secrets (15 minutes to configure)  
⚠️ EKS addons (10 minutes to install)  
⚠️ First pipeline run (needs testing)  

---

## 🚀 Next Steps

1. Run `./scripts/fix-kubectl-access.sh`
2. Configure GitHub secrets
3. Test the CI/CD pipeline
4. Deploy monitoring stack
5. Run end-to-end tests

**Estimated Time**: 2-4 hours to production-ready

---

## 📞 Support

- **Documentation**: `/docs` folder
- **Scripts**: `/scripts` folder
- **Issues**: Check `INFRASTRUCTURE_STATUS.md`
- **Emergency**: See `OPERATIONS_RUNBOOK.md`

---

**Welcome to your secure ML Model Supply Chain!** 🎉
