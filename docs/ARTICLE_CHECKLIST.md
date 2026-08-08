# 📸 Article Screenshot Checklist

Print this and check off as you capture each screenshot!

---

## 🎯 Essential Screenshots (Must Have)

### Setup & Infrastructure (10 screenshots)
- [ ] **01**: Project directory structure (`tree -L 2`)
- [ ] **02**: Terraform plan output
- [ ] **03**: AWS EKS cluster showing ACTIVE
- [ ] **04**: kubectl get nodes (all 4 Ready)
- [ ] **05**: AWS ECR repository created
- [ ] **06**: Kyverno pods running
- [ ] **07**: Cluster policies list
- [ ] **08**: GitHub secrets configured (list view)
- [ ] **09**: GitHub Actions workflow file
- [ ] **10**: Namespace created (`kubectl get ns ml-staging`)

### Local Pipeline (8 screenshots)
- [ ] **11**: Model training output
- [ ] **12**: Generated artifacts tree
- [ ] **13**: SBOM JSON content (pretty-printed)
- [ ] **14**: SLSA provenance JSON
- [ ] **15**: Cosign signing success
- [ ] **16**: Signature files created
- [ ] **17**: OPA policy evaluation (ALLOWED)
- [ ] **18**: Local test success summary

### GitHub Actions Pipeline (10 screenshots)
- [ ] **19**: Git push triggering pipeline
- [ ] **20**: GitHub Actions overview (runs list)
- [ ] **21**: Pipeline in progress (all 5 jobs)
- [ ] **22**: Train-and-attest job logs
- [ ] **23**: Security-scan job logs
- [ ] **24**: Policy-gate job logs (passing)
- [ ] **25**: Build-container job logs
- [ ] **26**: Deploy-staging job logs
- [ ] **27**: Pipeline complete (all green ✅)
- [ ] **28**: Job timing breakdown

### Deployment & Verification (10 screenshots)
- [ ] **29**: ECR images with tags
- [ ] **30**: `kubectl get all -n ml-staging`
- [ ] **31**: Pod details (annotations with SBOM refs)
- [ ] **32**: Pod logs (signature verification)
- [ ] **33**: Port-forward running
- [ ] **34**: Health check response
- [ ] **35**: Prediction request & response
- [ ] **36**: Attestations API endpoint
- [ ] **37**: Resource usage (`kubectl top`)
- [ ] **38**: Kyverno admission logs

### Security Features (6 screenshots)
- [ ] **39**: Cosign image verification success
- [ ] **40**: Kyverno BLOCKING unsigned deployment
- [ ] **41**: Policy violation event
- [ ] **42**: Signature verification in pod logs
- [ ] **43**: SLSA provenance details
- [ ] **44**: SBOM showing dependencies

---

## ⭐ Nice-to-Have Screenshots (Optional)

### Advanced Features (5 screenshots)
- [ ] **45**: AWS Cost Explorer breakdown
- [ ] **46**: Terraform state list
- [ ] **47**: Deployment history (`rollout history`)
- [ ] **48**: ECR vulnerability scan results
- [ ] **49**: Network policy details

### Comparison & Context (3 screenshots)
- [ ] **50**: Before/After comparison table
- [ ] **51**: Traditional vs Secure workflow
- [ ] **52**: Terraform destroy output

---

## 🎬 Animated GIFs (Optional but Engaging)

- [ ] **GIF 1**: Full pipeline from push to deployment (60 sec)
- [ ] **GIF 2**: Making predictions in real-time (15 sec)
- [ ] **GIF 3**: Kyverno blocking unsigned image (10 sec)
- [ ] **GIF 4**: Terraform apply progress (30 sec)

---

## 📊 Diagrams to Create

### Architecture Diagrams
- [ ] **Diagram 1**: High-level architecture
  - GitHub → GitHub Actions → ECR → EKS
  
- [ ] **Diagram 2**: Security flow
  - Sign → Verify → Policy → Deploy → Verify
  
- [ ] **Diagram 3**: Pipeline stages
  - 5 jobs with inputs/outputs
  
- [ ] **Diagram 4**: Kyverno admission control
  - Deployment → Kyverno → Allow/Deny → Kubernetes

### Comparison Tables
- [ ] **Table 1**: Traditional vs Secure Supply Chain
- [ ] **Table 2**: Cost breakdown
- [ ] **Table 3**: Security features matrix
- [ ] **Table 4**: Tool comparison (Cosign, OPA, Kyverno)

---

## 🎨 Screenshot Quality Checklist

For each screenshot, ensure:

- [ ] Terminal size is consistent (120x40 recommended)
- [ ] Font is readable (14pt minimum)
- [ ] Colors are visible (consider dark/light theme)
- [ ] No sensitive information visible (tokens, keys, passwords)
- [ ] Relevant information is in focus
- [ ] Timestamp/context is visible where needed
- [ ] File is saved with descriptive name
- [ ] Resolution is high enough (at least 1920px wide)

---

## 📝 Captions to Write

For your article, prepare captions for key screenshots:

### Example Captions:

**Screenshot 03** (EKS Cluster):
> "EKS cluster successfully deployed and running in active state with 4 nodes across 2 node groups"

**Screenshot 17** (OPA Evaluation):
> "Policy evaluation shows all security requirements met: signed artifacts, valid SBOMs, and SLSA provenance"

**Screenshot 27** (Pipeline Complete):
> "Complete CI/CD pipeline execution showing all 5 jobs passing: training, scanning, policy enforcement, container build, and deployment"

**Screenshot 35** (Prediction):
> "API response showing successful prediction with verified signature status - the model's cryptographic signature was validated at runtime"

**Screenshot 40** (Kyverno Blocking):
> "Kyverno policy engine successfully blocking deployment of unsigned container image, demonstrating zero-trust security"

---

## 🎯 Article Flow with Screenshots

### Section 1: Introduction
**Screenshots needed**: 1-2
- Traditional insecure deployment
- Project overview

### Section 2: Architecture
**Screenshots needed**: 3-5
- Directory structure
- Infrastructure diagram
- Component overview

### Section 3: Setup
**Screenshots needed**: 6-10
- Terraform deployment
- EKS cluster
- Infrastructure verification

### Section 4: Local Testing
**Screenshots needed**: 8-10
- Training model
- Generating SBOMs
- Signing artifacts
- Policy evaluation

### Section 5: CI/CD Pipeline
**Screenshots needed**: 10-12
- GitHub Actions setup
- Pipeline execution
- Each job's output
- Success confirmation

### Section 6: Security Features
**Screenshots needed**: 6-8
- Cosign verification
- Kyverno policies
- Policy enforcement
- Signature validation

### Section 7: Deployment
**Screenshots needed**: 6-8
- Kubernetes resources
- Pod details
- API testing
- Verification

### Section 8: Results
**Screenshots needed**: 2-3
- Working API
- Metrics
- Comparison table

---

## 💾 File Organization

Create folders for your screenshots:

```bash
mkdir -p ~/article-screenshots/{setup,pipeline,security,deployment,diagrams}

# Move screenshots as you take them:
# ~/article-screenshots/setup/01-terraform-plan.png
# ~/article-screenshots/pipeline/19-github-actions-running.png
# ~/article-screenshots/security/39-cosign-verification.png
# etc.
```

---

## ⏱️ Time Estimates

**Essential screenshots (44)**: ~2-3 hours
- Setup phase: 30 min
- Pipeline execution: 1 hour (waiting for deployment)
- Testing & verification: 45 min
- Security demonstrations: 30 min

**Optional screenshots (8)**: ~1 hour
**Diagrams (4)**: ~2 hours
**Captions & annotations**: ~1 hour

**Total time**: 6-7 hours for complete article assets

---

## 🚀 Quick Capture Commands

**Save these for quick screenshot capturing:**

```bash
# Terminal setup
export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
clear

# Pretty JSON output
alias prettyjson='jq "."'

# Kubernetes shortcuts
alias k='kubectl'
alias kgp='kubectl get pods -n ml-staging'
alias kgd='kubectl get deployments -n ml-staging'
alias klogs='kubectl logs -n ml-staging -l app=model-server --tail=50'

# Quick status check
check_status() {
  echo "=== Cluster Status ==="
  kubectl get nodes
  echo ""
  echo "=== Deployment Status ==="
  kubectl get all -n ml-staging
  echo ""
  echo "=== Recent Events ==="
  kubectl get events -n ml-staging --sort-by='.lastTimestamp' | tail -5
}
```

---

## 🎬 Recording Tips

### For Terminal Recordings:
1. **Clear screen** before starting
2. **Type slower** than normal
3. **Pause** before important output
4. **Use comments** to explain: `# This will sign the model`
5. **Show errors** (and fixes) - it's educational!

### For Browser Recordings:
1. **Close unnecessary tabs**
2. **Zoom to 100%**
3. **Hide bookmarks bar**
4. **Use a clean browser profile**
5. **Navigate deliberately** (don't rush)

### For Diagrams:
1. **Keep it simple** - one concept per diagram
2. **Use consistent colors** - same color for same component
3. **Add legends** if using colors/symbols
4. **Label everything** clearly
5. **Show data flow** with arrows

---

## ✅ Pre-Publication Checklist

Before publishing, verify you have:

- [ ] All essential screenshots captured
- [ ] Screenshots are high resolution
- [ ] No sensitive data visible (API keys, passwords)
- [ ] Consistent naming convention
- [ ] Captions written for each screenshot
- [ ] Diagrams are polished and professional
- [ ] Screenshots are annotated where helpful
- [ ] File sizes are optimized (use ImageOptim or similar)
- [ ] Alt text prepared for accessibility
- [ ] Screenshots are organized in folders

---

## 📤 Export Formats

### For Web Articles:
- **Format**: PNG or WebP
- **Resolution**: 1920px wide (2x for retina)
- **Compression**: 80-90% quality
- **File size**: < 500KB per image

### For Print/PDF:
- **Format**: PNG or PDF
- **Resolution**: 300 DPI
- **Color mode**: CMYK for print, RGB for digital
- **File size**: Not critical

### For Social Media:
- **Twitter**: 1200x675px
- **LinkedIn**: 1200x627px
- **Format**: PNG or JPG

---

## 🎯 Priority Order

If you're short on time, capture in this order:

**Must have (30 min)**:
1. EKS cluster running
2. GitHub Actions pipeline success
3. Kyverno blocking unsigned image
4. API prediction working
5. OPA policy evaluation

**Should have (1 hour)**:
6. Local testing pipeline
7. Terraform deployment
8. Pipeline job details
9. Pod logs with verification
10. Architecture diagram

**Nice to have (2+ hours)**:
11. All other screenshots
12. Animated GIFs
13. Detailed diagrams
14. Cost breakdowns

---

**Print this checklist and mark them off as you go!** ✓

Good luck with your article! 📝✨
