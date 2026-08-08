# 👋 Start Here - Complete Guide to Testing the Full Pipeline

Welcome! You want to set up Kubernetes and test the full CI/CD pipeline on GitHub Actions. I've created everything you need!

---

## 📚 What I've Created For You

I've prepared **4 comprehensive guides** to help you:

### 1. **QUICK_START.md** ⚡
**5-minute overview** - Just want to run it? Start here!
- One command to rule them all
- Quick verification steps
- Common issues & fixes

👉 **Read this first**: `cat QUICK_START.md`

### 2. **SETUP_AND_TEST_GUIDE.md** 📖
**Complete step-by-step guide** - Want to understand everything? Read this!
- Detailed prerequisites
- Manual setup instructions
- Troubleshooting section
- Verification checklist

👉 **For deep understanding**: `cat SETUP_AND_TEST_GUIDE.md`

### 3. **DEPLOYMENT_FLOW.md** 🎨
**Visual diagram** - Want to see the big picture? Check this!
- ASCII art flow diagram
- Shows every step visually
- Explains what happens where

👉 **For visual learners**: `cat DEPLOYMENT_FLOW.md`

### 4. **setup-and-test-full-pipeline.sh** 🤖
**Automation script** - Want it done automatically? Run this!
- Fully automated setup
- Interactive prompts
- Status updates at each step

👉 **For automation**: `./scripts/setup-and-test-full-pipeline.sh`

---

## 🚀 Quickest Path to Success

### Option 1: Automated (Recommended)

```bash
cd /Users/admin/Documents/Documents/Projects-2026/model-supply-chain

# Make script executable
chmod +x scripts/setup-and-test-full-pipeline.sh

# Run it!
./scripts/setup-and-test-full-pipeline.sh
```

**Time**: 40-45 minutes (mostly waiting for AWS)  
**Difficulty**: Easy ⭐  
**What it does**: Everything automatically!

### Option 2: Manual (For Learning)

Follow the step-by-step guide in `SETUP_AND_TEST_GUIDE.md`:

```bash
cat SETUP_AND_TEST_GUIDE.md
```

**Time**: 2-3 hours  
**Difficulty**: Medium ⭐⭐⭐  
**What you learn**: How everything works under the hood

---

## 🎯 What You're Building

A **production-grade ML model deployment pipeline** with:

```
┌─────────────────────────────────────────────────────────┐
│                 GitHub (Code Push)                      │
│                         │                               │
│                         ▼                               │
│         ┌────────────────────────────────┐             │
│         │   GitHub Actions Pipeline      │             │
│         │                                │             │
│         │  1. Train Model                │             │
│         │  2. Generate SBOMs             │             │
│         │  3. Sign with Cosign           │             │
│         │  4. Security Scan              │             │
│         │  5. Policy Check (OPA)         │             │
│         │  6. Build Container            │             │
│         │  7. Sign Image                 │             │
│         │  8. Push to ECR                │             │
│         └────────────────────────────────┘             │
│                         │                               │
└─────────────────────────┼───────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│              AWS EKS (Kubernetes)                       │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │              Kyverno Gateway                     │  │
│  │  (Verifies signatures & attestations)           │  │
│  │                     │                            │  │
│  │                     ▼                            │  │
│  │   ✅ Signed?  ✅ SLSA?  ✅ SBOM?                 │  │
│  └──────────────────────────────────────────────────┘  │
│                         │                               │
│                         ▼                               │
│  ┌──────────────────────────────────────────────────┐  │
│  │         Model Server (2 pods)                    │  │
│  │  • Verifies signature on startup                │  │
│  │  • Serves predictions via API                   │  │
│  │  • Provides health checks                       │  │
│  │  • Exposes provenance data                      │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Security Features**:
- 🔐 Cryptographic signing (Cosign)
- 📦 Software Bill of Materials (SBOMs)
- 📜 SLSA provenance (who/what/when/where)
- 🚦 Policy enforcement (OPA + Kyverno)
- ✅ Runtime verification (server checks signatures)

---

## 📋 Prerequisites

Before you start, install these tools:

```bash
# Install Homebrew (if needed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install awscli terraform kubectl cosign opa gh

# Configure AWS
aws configure
# Enter: Access Key, Secret Key, Region (us-east-1)

# Authenticate GitHub CLI
gh auth login
```

**Verify installations:**
```bash
aws --version       # Should show v2.x
terraform --version # Should show v1.x
kubectl version --client
cosign version
opa version
gh --version
```

---

## 🎬 The Journey

Here's what will happen:

### Phase 1: Infrastructure Setup (20 min)
- Deploy EKS cluster to AWS
- Create 4 EC2 nodes (2 system + 2 ML)
- Setup ECR container registry
- Configure IAM roles for GitHub

### Phase 2: Security Setup (5 min)
- Install Kyverno policy engine
- Generate Cosign signing keys
- Configure GitHub secrets
- Create Kubernetes namespace

### Phase 3: Testing (10 min)
- Test local pipeline
- Trigger GitHub Actions
- Monitor deployment
- Verify everything works

### Phase 4: Verification (5 min)
- Check cluster health
- Test API endpoints
- Verify signatures
- Review logs

**Total Time**: ~40-45 minutes

---

## 💰 Cost

**AWS Charges**: ~$206/month

Breakdown:
- EKS control plane: $73
- EC2 nodes (4 instances): $90
- NAT Gateway: $33
- Storage/ECR: $10

**To destroy everything** (stops all charges immediately):
```bash
./scripts/terraform-destroy-all.sh
```

---

## 🆘 Need Help?

### Start with these:
1. **Quick reference**: `QUICK_START.md`
2. **Full guide**: `SETUP_AND_TEST_GUIDE.md`
3. **Visual flow**: `DEPLOYMENT_FLOW.md`

### Having issues?
1. Check common issues in `QUICK_START.md`
2. Read troubleshooting in `SETUP_AND_TEST_GUIDE.md`
3. Review existing docs in `docs/` folder

### Still stuck?
```bash
# Check cluster status
kubectl get nodes

# View deployment status
kubectl get all -n ml-staging

# Check logs
kubectl logs -n ml-staging -l app=model-server --tail=50

# Verify AWS access
aws sts get-caller-identity

# Check GitHub Actions
gh run list --workflow=model-pipeline.yml
```

---

## 📊 Success Checklist

You'll know it works when you see:

- [ ] ✅ 4 nodes showing as "Ready"
- [ ] ✅ 2 pods running in ml-staging namespace
- [ ] ✅ GitHub Actions pipeline shows green checkmark
- [ ] ✅ ECR has container images
- [ ] ✅ Health endpoint returns OK
- [ ] ✅ Predictions work via API
- [ ] ✅ Kyverno policies are enforced

Test with:
```bash
kubectl port-forward -n ml-staging svc/model-server 8080:80 &
curl http://localhost:8080/health
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [5.1, 3.5, 1.4, 0.2]}'
```

---

## 🎓 What You'll Learn

By the end of this, you'll understand:

1. **Kubernetes (K8s)**: Container orchestration
2. **EKS**: Managed Kubernetes on AWS
3. **Kyverno**: Policy enforcement for K8s
4. **Cosign**: Artifact signing & verification
5. **SLSA**: Supply chain security framework
6. **SBOMs**: Software Bill of Materials
7. **GitHub Actions**: CI/CD automation
8. **Terraform**: Infrastructure as Code
9. **Zero-trust**: Verify at every stage

---

## 🚦 Choose Your Path

### Path A: Just Make It Work (Easiest)
1. Install prerequisites (5 min)
2. Run `./scripts/setup-and-test-full-pipeline.sh`
3. Wait 40 minutes
4. ✅ Done!

### Path B: Understand Everything (Best for Learning)
1. Read `SETUP_AND_TEST_GUIDE.md`
2. Follow step-by-step
3. Run each command manually
4. Learn how it all connects

### Path C: Quick Overview First
1. Read `QUICK_START.md` (2 min)
2. Run automated script
3. Read full guide while waiting
4. Verify and explore

---

## 📁 Project Structure

```
model-supply-chain/
├── START_HERE.md                    ← You are here!
├── QUICK_START.md                   ← 5-minute guide
├── SETUP_AND_TEST_GUIDE.md          ← Complete guide
├── DEPLOYMENT_FLOW.md               ← Visual diagram
│
├── scripts/
│   ├── setup-and-test-full-pipeline.sh  ← Automation!
│   ├── terraform-apply-all.sh           ← Deploy infra
│   ├── terraform-destroy-all.sh         ← Cleanup
│   └── e2e-demo.sh                      ← Local test
│
├── terraform/                       ← Infrastructure code
│   ├── main.tf                      ← EKS cluster
│   ├── variables.tf                 ← Configuration
│   └── outputs.tf                   ← Export values
│
├── src/                             ← Application code
│   ├── train_model.py               ← Train ML model
│   ├── model_server.py              ← API server
│   ├── sign_artifact.py             ← Signing logic
│   └── generate_sbom.py             ← SBOM generation
│
├── k8s/                             ← Kubernetes configs
│   ├── deployment.yaml              ← Model server
│   └── kyverno-policy.yaml          ← Security policies
│
├── .github/workflows/               ← CI/CD pipelines
│   ├── model-pipeline.yml           ← Main pipeline
│   └── infra.yml                    ← Infra deployment
│
└── docs/                            ← Additional docs
    ├── GETTING_STARTED.md
    ├── OPERATIONS_RUNBOOK.md
    ├── GITHUB_ACTIONS_SETUP.md
    └── technical/
        └── ARCHITECTURE.md
```

---

## 🎯 Your Next Steps

### Right Now (5 minutes)
1. Read `QUICK_START.md` for overview
2. Verify prerequisites are installed
3. Configure AWS and GitHub credentials

### Then (40 minutes)
1. Run `./scripts/setup-and-test-full-pipeline.sh`
2. Follow the prompts
3. Wait for deployment to complete
4. Verify everything works

### After That (ongoing)
1. Explore the deployed system
2. Test the API endpoints
3. Customize for your models
4. Read the full documentation

---

## 🎉 Ready?

**Easiest start**:
```bash
cd /Users/admin/Documents/Documents/Projects-2026/model-supply-chain
cat QUICK_START.md
```

**For deep dive**:
```bash
cat SETUP_AND_TEST_GUIDE.md
```

**To see the flow**:
```bash
cat DEPLOYMENT_FLOW.md
```

**To run it now**:
```bash
chmod +x scripts/setup-and-test-full-pipeline.sh
./scripts/setup-and-test-full-pipeline.sh
```

---

## 💡 Pro Tips

1. **Read QUICK_START.md first** - It's short and covers 80% of what you need
2. **Use the automation script** - It handles edge cases and gives you feedback
3. **Keep terminal logs** - Copy output in case you need to troubleshoot
4. **Test locally first** - The script runs local tests before GitHub Actions
5. **Don't skip secrets setup** - GitHub Actions won't work without proper secrets

---

## 🏆 What Success Looks Like

When everything works, you'll see:

```bash
$ kubectl get all -n ml-staging

NAME                               READY   STATUS    RESTARTS   AGE
pod/model-server-abc123-def       1/1     Running   0          5m
pod/model-server-abc123-ghi       1/1     Running   0          5m

NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
service/model-server   ClusterIP   10.100.123.45   <none>        80/TCP

NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/model-server   2/2     2            2           5m
```

```bash
$ curl http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [5.1, 3.5, 1.4, 0.2]}'

{
  "prediction": 0,
  "model_version": "1.0.0",
  "model_hash": "abc123...",
  "verified": true,          ← Signature verified!
  "slsa_level": 3,           ← SLSA Level 3 compliant!
  "build_platform": "github-actions"
}
```

That's supply chain security in action! 🔐

---

**Let's get started! 🚀**

Choose your path above and begin your journey to production-grade ML deployment.

Good luck! You've got this. 💪
