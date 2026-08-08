# 📸 Screenshot Guide for Article/Blog Post

This guide shows you exactly what screenshots to take for a compelling article about the ML Model Supply Chain project.

---

## 🎯 Article Structure & Screenshots

### Section 1: Introduction - "The Problem"

**Screenshot 1: Traditional ML Deployment (Before)**
```bash
# Show a simple, insecure deployment
echo "Traditional ML Deployment:" > /tmp/traditional.txt
echo "docker build -t my-model ." >> /tmp/traditional.txt
echo "docker push my-model" >> /tmp/traditional.txt
echo "kubectl apply -f deployment.yaml" >> /tmp/traditional.txt
echo "" >> /tmp/traditional.txt
echo "⚠️  No signing" >> /tmp/traditional.txt
echo "⚠️  No provenance" >> /tmp/traditional.txt
echo "⚠️  No verification" >> /tmp/traditional.txt
cat /tmp/traditional.txt
```

**Take screenshot of**: Terminal showing this unsecured workflow

---

### Section 2: Architecture Overview

**Screenshot 2: Project Structure**
```bash
cd /Users/admin/Documents/Documents/Projects-2026/model-supply-chain
tree -L 2 -I '.git|.terraform|__pycache__|*.pyc'
```

**Take screenshot of**: Directory tree showing organized project structure

**Screenshot 3: README.md in GitHub**
- Open: https://github.com/[your-username]/model-supply-chain
- **Take screenshot of**: Clean README with badges and overview

---

### Section 3: Infrastructure Deployment

**Screenshot 4: Terraform Plan**
```bash
cd terraform
terraform plan -var="environment=staging" | head -50
```

**Take screenshot of**: Terraform showing what will be created (EKS, VPC, etc.)

**Screenshot 5: Terraform Apply in Progress**
```bash
# While terraform apply is running
terraform apply -var="environment=staging"
```

**Take screenshot of**: Terraform creating resources (showing progress)

**Screenshot 6: AWS EKS Console**
- Open: AWS Console → EKS → Clusters
- **Take screenshot of**: EKS cluster showing "ACTIVE" status
- Show: Cluster name, version, status, node groups

**Screenshot 7: Kubectl Get Nodes**
```bash
kubectl get nodes -o wide
```

**Take screenshot of**: All 4 nodes in "Ready" state with details

**Screenshot 8: AWS ECR Console**
- Open: AWS Console → ECR → Repositories
- **Take screenshot of**: ECR repository created and ready

---

### Section 4: Local Pipeline Testing

**Screenshot 9: Training Model with Provenance**
```bash
cd /Users/admin/Documents/Documents/Projects-2026/model-supply-chain
python3 src/train_model.py
```

**Take screenshot of**: Model training output showing:
- Training progress
- Accuracy metrics
- Provenance creation
- ✅ Success message

**Screenshot 10: Generated Artifacts**
```bash
tree artifacts/
```

**Take screenshot of**: Directory tree showing:
- model.pkl
- metadata.json
- sbom/ directory
- attestations/ directory

**Screenshot 11: SBOM Content**
```bash
cat artifacts/sbom/code-sbom.json | jq '.' | head -40
```

**Take screenshot of**: Pretty-printed SBOM showing dependencies

**Screenshot 12: SLSA Provenance**
```bash
cat artifacts/attestations/provenance.json | jq '.' | head -30
```

**Take screenshot of**: Provenance showing builder, materials, parameters

**Screenshot 13: Signing with Cosign**
```bash
python3 src/sign_artifact.py artifacts
```

**Take screenshot of**: Cosign signing output with ✅ success messages

**Screenshot 14: Signature Files**
```bash
ls -lh artifacts/*.sig artifacts/sbom/*.sig
```

**Take screenshot of**: All signature files created

**Screenshot 15: Policy Evaluation (OPA)**
```bash
python3 policies/test_policy.py artifacts
```

**Take screenshot of**: Policy checks showing:
- ✅ Signature verified
- ✅ SBOMs present
- ✅ Provenance valid
- ✅ Quality threshold met
- Result: ALLOWED

---

### Section 5: Kyverno Setup

**Screenshot 16: Installing Kyverno**
```bash
kubectl apply -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml
kubectl get pods -n kyverno
```

**Take screenshot of**: Kyverno pods running

**Screenshot 17: Kyverno Policies**
```bash
kubectl get clusterpolicies
```

**Take screenshot of**: Supply chain policies listed

**Screenshot 18: Policy Details**
```bash
kubectl describe clusterpolicy verify-model-supply-chain | head -60
```

**Take screenshot of**: Policy rules showing signature verification requirements

---

### Section 6: GitHub Actions Setup

**Screenshot 19: GitHub Secrets Configuration**
- Open: GitHub → Settings → Secrets and variables → Actions
- **Take screenshot of**: List of configured secrets (values hidden)
- Show: AWS_ACCOUNT_ID, AWS_REGION, EKS_CLUSTER_NAME, etc.

**Screenshot 20: GitHub Actions Workflow File**
```bash
cat .github/workflows/model-pipeline.yml | head -60
```

**Take screenshot of**: Workflow YAML showing job structure

**Screenshot 21: Triggering the Pipeline**
```bash
git add .
git commit -m "test: trigger full pipeline"
git push origin main
```

**Take screenshot of**: Git push triggering the pipeline

---

### Section 7: Pipeline Execution

**Screenshot 22: GitHub Actions Overview**
- Open: GitHub → Actions tab
- **Take screenshot of**: Pipeline runs list showing recent execution

**Screenshot 23: Pipeline Running**
- Click on a running workflow
- **Take screenshot of**: All 5 jobs with progress indicators
- Show: train-and-attest, security-scan, policy-gate, build-container, deploy-staging

**Screenshot 24: Train & Attest Job**
- Click on "train-and-attest" job
- **Take screenshot of**: Logs showing:
  - Model training
  - SBOM generation
  - Cosign signing (keyless)
  - Artifact upload

**Screenshot 25: Security Scan Job**
- Click on "security-scan" job
- **Take screenshot of**: Vulnerability scanning with Grype

**Screenshot 26: Policy Gate Job**
- Click on "policy-gate" job
- **Take screenshot of**: OPA policy evaluation
- Show: All checks passing ✅

**Screenshot 27: Build Container Job**
- Click on "build-container" job
- **Take screenshot of**: 
  - Docker build output
  - Image push to ECR
  - Cosign signing the image
  - Signature verification

**Screenshot 28: Deploy Staging Job**
- Click on "deploy-staging" job
- **Take screenshot of**:
  - kubectl apply output
  - Rollout status
  - Deployment success ✅

**Screenshot 29: Pipeline Complete**
- Back to workflow overview
- **Take screenshot of**: All jobs green with checkmarks ✅

---

### Section 8: Verification

**Screenshot 30: ECR with Signed Images**
- Open: AWS Console → ECR → model-supply-chain-staging/model-server
- **Take screenshot of**: Images with tags, pushed timestamp, size

**Screenshot 31: ECR Image Scan Results**
- Click on an image → View vulnerabilities
- **Take screenshot of**: Vulnerability scan results

**Screenshot 32: Kubernetes Deployment**
```bash
kubectl get all -n ml-staging
```

**Take screenshot of**: Deployment, pods, service all showing

**Screenshot 33: Pod Details**
```bash
kubectl describe pod -n ml-staging -l app=model-server | head -80
```

**Take screenshot of**: Pod details showing:
- Image name
- Annotations (with SBOM and provenance refs)
- Status: Running
- Events: Pulled, Created, Started

**Screenshot 34: Pod Logs**
```bash
kubectl logs -n ml-staging -l app=model-server --tail=30
```

**Take screenshot of**: Model server logs showing:
- Signature verification
- Model loaded
- Server started
- Listening on port 8080

**Screenshot 35: Kyverno Admission Decision**
```bash
kubectl get events -n ml-staging --sort-by='.lastTimestamp' | grep -i policy
```

**Take screenshot of**: Events showing Kyverno allowed the deployment

---

### Section 9: Testing the API

**Screenshot 36: Port Forward**
```bash
kubectl port-forward -n ml-staging svc/model-server 8080:80
```

**Take screenshot of**: Port-forward running

**Screenshot 37: Health Check**
```bash
curl http://localhost:8080/health
```

**Take screenshot of**: Health endpoint returning OK

**Screenshot 38: Making a Prediction**
```bash
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [5.1, 3.5, 1.4, 0.2]}' | jq '.'
```

**Take screenshot of**: Prediction response showing:
- prediction: 0
- model_version: 1.0.0
- verified: true ← Key point!
- model_hash

**Screenshot 39: Viewing Attestations**
```bash
curl http://localhost:8080/attestations | jq '.' | head -40
```

**Take screenshot of**: Provenance data exposed via API

---

### Section 10: Security Features

**Screenshot 40: Cosign Verification**
```bash
# Verify container image signature
export IMAGE=$(kubectl get deployment model-server -n ml-staging -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "Image: $IMAGE"

COSIGN_EXPERIMENTAL=1 cosign verify $IMAGE \
  --certificate-identity-regexp='https://github.com/.*' \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com
```

**Take screenshot of**: Cosign verification showing valid signature

**Screenshot 41: Attempting Unsigned Deployment (Should Fail)**

Create a test file:
```bash
cat > /tmp/unsigned-deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: unsigned-test
  namespace: ml-staging
spec:
  replicas: 1
  selector:
    matchLabels:
      app: unsigned
  template:
    metadata:
      labels:
        app: unsigned
    spec:
      containers:
      - name: nginx
        image: nginx:latest
EOF

kubectl apply -f /tmp/unsigned-deployment.yaml
```

**Take screenshot of**: Kyverno BLOCKING the deployment with error message

**Screenshot 42: Kyverno Policy Violation**
```bash
kubectl get events -n ml-staging --sort-by='.lastTimestamp' | tail -5
```

**Take screenshot of**: Event showing policy violation

---

### Section 11: Monitoring & Observability

**Screenshot 43: Resource Usage**
```bash
kubectl top nodes
kubectl top pods -n ml-staging
```

**Take screenshot of**: CPU and memory usage

**Screenshot 44: Deployment History**
```bash
kubectl rollout history deployment/model-server -n ml-staging
```

**Take screenshot of**: Rollout revisions

**Screenshot 45: Terraform State**
```bash
cd terraform
terraform state list | head -20
```

**Take screenshot of**: All managed resources

---

### Section 12: Cost & Cleanup

**Screenshot 46: AWS Cost Explorer**
- Open: AWS Console → Cost Explorer
- **Take screenshot of**: Daily costs breakdown
- Show: EC2, EKS, ECR costs

**Screenshot 47: Destroying Resources**
```bash
./scripts/terraform-destroy-all.sh
```

**Take screenshot of**: Terraform destroying resources

---

## 📊 Bonus Screenshots (Optional but Powerful)

### Architecture Diagrams

**Screenshot 48: VS Code with Architecture**
- Open the project in VS Code
- **Take screenshot of**: Split view with code and docs

**Screenshot 49: Comparing Before/After**

Create comparison:
```bash
cat > /tmp/comparison.txt <<EOF
BEFORE (Traditional):                 AFTER (Secure Supply Chain):
─────────────────────                ──────────────────────────────
❌ No signing                         ✅ Cosign signatures
❌ No provenance                      ✅ SLSA provenance
❌ No SBOM                            ✅ CycloneDX SBOMs
❌ Manual deployment                  ✅ Automated CI/CD
❌ No policy enforcement              ✅ Kyverno policies
❌ No runtime verification            ✅ Server verifies on startup
❌ No audit trail                     ✅ Complete transparency log
EOF
cat /tmp/comparison.txt
```

**Take screenshot of**: Side-by-side comparison

---

## 🎨 Screenshot Best Practices

### Terminal Screenshots

1. **Use a clean terminal theme**
   - Light background for print articles
   - Dark background for digital/tech blogs

2. **Set appropriate terminal size**
   ```bash
   # Resize for better readability
   printf '\e[8;40;120t'
   ```

3. **Add syntax highlighting**
   ```bash
   # Install bat for better output
   brew install bat
   bat artifacts/sbom/code-sbom.json
   ```

4. **Clear scrollback before important commands**
   ```bash
   clear
   ```

### Browser Screenshots

1. **Zoom to 100%** for consistency
2. **Hide bookmarks bar** (cleaner look)
3. **Use incognito mode** (no extensions)
4. **Capture full page** if needed (use browser extension)

### AWS Console Screenshots

1. **Expand relevant sections**
2. **Show resource names clearly**
3. **Include region in the screenshot**
4. **Highlight important information**

---

## 📝 Screenshot Naming Convention

Save your screenshots with descriptive names:

```
01-problem-traditional-deployment.png
02-project-structure.png
03-terraform-plan.png
04-terraform-apply-progress.png
05-eks-cluster-active.png
06-kubectl-get-nodes.png
07-ecr-repository.png
08-train-model-output.png
09-artifacts-directory.png
10-sbom-content.png
11-slsa-provenance.png
12-cosign-signing.png
13-signature-files.png
14-opa-policy-evaluation.png
15-kyverno-installation.png
16-kyverno-policies-list.png
17-policy-details.png
18-github-secrets.png
19-workflow-yaml.png
20-git-push-trigger.png
21-github-actions-overview.png
22-pipeline-running.png
23-train-attest-job.png
24-security-scan-job.png
25-policy-gate-job.png
26-build-container-job.png
27-deploy-staging-job.png
28-pipeline-complete.png
29-ecr-signed-images.png
30-ecr-scan-results.png
31-kubernetes-deployment.png
32-pod-details.png
33-pod-logs.png
34-kyverno-admission.png
35-port-forward.png
36-health-check.png
37-prediction-request.png
38-attestations-api.png
39-cosign-verification.png
40-kyverno-blocking-unsigned.png
41-policy-violation-event.png
42-resource-usage.png
43-deployment-history.png
44-terraform-state.png
45-aws-cost-breakdown.png
46-terraform-destroy.png
```

---

## 🎬 Video/GIF Captures (Optional)

For more engaging content, consider recording these as short GIFs:

### GIF 1: Full Pipeline Execution
```bash
# Record from git push to deployment
asciinema rec --title "Full Pipeline" pipeline.cast
git push origin main
# ... wait for pipeline ...
kubectl get pods -n ml-staging
asciinema play pipeline.cast
```

### GIF 2: Real-time Prediction
```bash
# Record making predictions
asciinema rec prediction.cast
for i in {1..5}; do
  curl -X POST http://localhost:8080/predict \
    -H "Content-Type: application/json" \
    -d '{"features": [5.1, 3.5, 1.4, 0.2]}' | jq '.prediction'
  sleep 1
done
asciinema play prediction.cast
```

### GIF 3: Kyverno Blocking Unsigned Image
```bash
# Record policy enforcement
asciinema rec kyverno-block.cast
kubectl apply -f unsigned-deployment.yaml
# Shows denial
asciinema play kyverno-block.cast
```

**Convert to GIF**:
```bash
# Install agg (asciinema gif generator)
cargo install --git https://github.com/asciinema/agg

# Convert
agg pipeline.cast pipeline.gif
```

---

## 📐 Diagram Creation Tools

For custom diagrams:

1. **Draw.io** (free, web-based)
   - Architecture diagrams
   - Flow charts
   - Component diagrams

2. **Excalidraw** (free, simple)
   - Hand-drawn style
   - Quick sketches
   - Export as PNG/SVG

3. **Mermaid** (code-based)
   ```bash
   # Install mmdc (mermaid CLI)
   npm install -g @mermaid-js/mermaid-cli
   
   # Create diagram
   cat > diagram.mmd <<EOF
   graph LR
     A[Code Push] --> B[GitHub Actions]
     B --> C[Build & Sign]
     C --> D[Push to ECR]
     D --> E[Kyverno Verifies]
     E --> F[Deploy to EKS]
   EOF
   
   # Generate image
   mmdc -i diagram.mmd -o diagram.png
   ```

---

## ✅ Final Checklist

Before publishing your article, ensure you have:

**Infrastructure:**
- [ ] EKS cluster status
- [ ] Node list
- [ ] ECR repository
- [ ] AWS costs

**Pipeline:**
- [ ] GitHub Actions workflow
- [ ] All 5 jobs running
- [ ] Pipeline completion
- [ ] Logs from each stage

**Security:**
- [ ] Cosign signing
- [ ] SBOM generation
- [ ] SLSA provenance
- [ ] OPA policy check
- [ ] Kyverno enforcement
- [ ] Signature verification

**Deployment:**
- [ ] Kubernetes resources
- [ ] Pod logs
- [ ] Health check
- [ ] Prediction working
- [ ] Attestations visible

**Comparison:**
- [ ] Before/after
- [ ] Traditional vs secure
- [ ] Benefits highlighted

---

## 🎯 Article Structure Suggestion

**Title Ideas:**
- "Building a Production-Grade ML Supply Chain with Kubernetes and Sigstore"
- "SLSA Level 3 Compliance for ML Models: A Complete Guide"
- "How We Secured Our ML Pipeline with Cosign, Kyverno, and EKS"

**Sections:**
1. **The Problem** (1-2 screenshots)
2. **Architecture Overview** (2-3 screenshots)
3. **Infrastructure Setup** (4-5 screenshots)
4. **Local Testing** (5-6 screenshots)
5. **CI/CD Pipeline** (8-10 screenshots)
6. **Security Features** (3-4 screenshots)
7. **Verification** (4-5 screenshots)
8. **Results & Benefits** (2-3 screenshots)
9. **Conclusion** (1 comparison screenshot)

**Total recommended**: 30-40 high-quality screenshots

---

## 💡 Pro Tips

1. **Annotate screenshots**: Add arrows, boxes, highlights
2. **Show progression**: Before → During → After
3. **Highlight key info**: Circle important values
4. **Add captions**: Explain what each screenshot shows
5. **Be consistent**: Same terminal theme throughout
6. **High resolution**: Capture at 2x for retina displays
7. **Crop properly**: Remove unnecessary whitespace
8. **Show real data**: Actual timestamps, hashes, IDs

---

**Ready to create an awesome article!** 📝✨

Follow this guide, take these screenshots, and you'll have compelling visual evidence of your secure ML supply chain in action!
