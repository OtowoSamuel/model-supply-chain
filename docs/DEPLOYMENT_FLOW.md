# Deployment Flow Diagram

## 🎯 Complete Setup & Test Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         YOUR LAPTOP                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Step 1: Run Setup Script                                          │
│  ┌────────────────────────────────────────────┐                    │
│  │ ./scripts/setup-and-test-full-pipeline.sh │                    │
│  └────────────────────────────────────────────┘                    │
│                          │                                          │
│                          ▼                                          │
│  ┌──────────────────────────────────────────────────────┐          │
│  │ Checks Prerequisites:                                │          │
│  │ ✓ AWS CLI      ✓ Terraform    ✓ kubectl            │          │
│  │ ✓ Cosign       ✓ OPA          ✓ GitHub CLI         │          │
│  └──────────────────────────────────────────────────────┘          │
│                          │                                          │
└──────────────────────────┼──────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         AWS CLOUD                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Step 2: Deploy Infrastructure (Terraform)                         │
│  ┌─────────────────────────────────────────────────────┐           │
│  │                    terraform apply                   │           │
│  │                                                      │           │
│  │  Creates:                                           │           │
│  │  • EKS Cluster (Kubernetes control plane)          │           │
│  │  • 4 EC2 Nodes (2 system + 2 ML)                   │           │
│  │  • ECR Repository (for Docker images)              │           │
│  │  • IAM Roles (GitHub Actions OIDC)                 │           │
│  │  • VPC, Subnets, Security Groups                   │           │
│  │  • S3 Bucket (Terraform state)                     │           │
│  └─────────────────────────────────────────────────────┘           │
│                          │                                          │
│                          ▼                                          │
│  ┌───────────────────────────────────────────────────────────┐     │
│  │           EKS CLUSTER (Kubernetes)                        │     │
│  │  ┌────────────────────────────────────────────────────┐  │     │
│  │  │  Node Group: system (2x t3.medium)                │  │     │
│  │  │  • kube-system pods                               │  │     │
│  │  │  • coredns                                        │  │     │
│  │  │  • kube-proxy                                     │  │     │
│  │  └────────────────────────────────────────────────────┘  │     │
│  │  ┌────────────────────────────────────────────────────┐  │     │
│  │  │  Node Group: ml-workload (2x t3.xlarge)           │  │     │
│  │  │  • ml-staging namespace                           │  │     │
│  │  │  • model-server pods (deployed later)             │  │     │
│  │  └────────────────────────────────────────────────────┘  │     │
│  └───────────────────────────────────────────────────────────┘     │
│                          │                                          │
└──────────────────────────┼──────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      BACK TO YOUR LAPTOP                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Step 3: Configure kubectl                                         │
│  ┌────────────────────────────────────────────────────┐            │
│  │ aws eks update-kubeconfig                          │            │
│  │ kubectl get nodes  ← Now you can control EKS!     │            │
│  └────────────────────────────────────────────────────┘            │
│                          │                                          │
│                          ▼                                          │
│  Step 4: Install Kyverno (Policy Engine)                           │
│  ┌────────────────────────────────────────────────────┐            │
│  │ kubectl apply -f kyverno-install.yaml              │            │
│  │ kubectl apply -f k8s/kyverno-policy.yaml           │            │
│  │                                                     │            │
│  │ Kyverno = TSA checkpoint for deployments           │            │
│  │ • Checks image signatures                          │            │
│  │ • Requires SLSA provenance                         │            │
│  │ • Blocks unsigned images                           │            │
│  └────────────────────────────────────────────────────┘            │
│                          │                                          │
│                          ▼                                          │
│  Step 5: Generate Cosign Keys                                      │
│  ┌────────────────────────────────────────────────────┐            │
│  │ cosign generate-key-pair                           │            │
│  │                                                     │            │
│  │ Creates:                                           │            │
│  │ • keys/cosign.key (PRIVATE - never commit!)       │            │
│  │ • keys/cosign.pub (PUBLIC - safe to share)        │            │
│  │                                                     │            │
│  │ Think: Private key = wax seal ring 💍             │            │
│  │        Public key = verify the seal ✅             │            │
│  └────────────────────────────────────────────────────┘            │
│                          │                                          │
└──────────────────────────┼──────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        GITHUB                                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Step 6: Configure Repository Secrets                              │
│  ┌────────────────────────────────────────────────────┐            │
│  │ Settings → Secrets → Actions                       │            │
│  │                                                     │            │
│  │ Add these secrets:                                 │            │
│  │ • AWS_ACCOUNT_ID      = 050083686295               │            │
│  │ • AWS_REGION          = us-east-1                  │            │
│  │ • AWS_ROLE_ARN        = (from Terraform)           │            │
│  │ • ECR_REPOSITORY      = model-.../model-server     │            │
│  │ • EKS_CLUSTER_NAME    = model-supply-chain-staging │            │
│  │ • COSIGN_PRIVATE_KEY  = (content of cosign.key)    │            │
│  │ • COSIGN_PASSWORD     = (your password)            │            │
│  └────────────────────────────────────────────────────┘            │
│                          │                                          │
└──────────────────────────┼──────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    YOUR LAPTOP (Testing)                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Step 7: Test Local Pipeline                                       │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                                                              │  │
│  │  1. Train Model                                             │  │
│  │     python src/train_model.py                               │  │
│  │     → Creates: artifacts/model.pkl                          │  │
│  │     → Creates: artifacts/metadata.json                      │  │
│  │     → Creates: artifacts/attestations/provenance.json       │  │
│  │                                                              │  │
│  │  2. Generate SBOMs (Ingredient Lists)                       │  │
│  │     python src/generate_sbom.py                             │  │
│  │     → Creates: artifacts/sbom/code-sbom.json                │  │
│  │     → Creates: artifacts/sbom/model-sbom.json               │  │
│  │                                                              │  │
│  │  3. Sign Everything with Cosign                             │  │
│  │     python src/sign_artifact.py artifacts                   │  │
│  │     → Creates: artifacts/model.pkl.sig                      │  │
│  │     → Creates: artifacts/sbom/*.sig                         │  │
│  │                                                              │  │
│  │  4. Check Policies (OPA)                                    │  │
│  │     python policies/test_policy.py artifacts                │  │
│  │     ✓ Is signed?                                            │  │
│  │     ✓ Has SBOMs?                                            │  │
│  │     ✓ Has provenance?                                       │  │
│  │     ✓ Meets quality threshold?                              │  │
│  │                                                              │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                     │
│                          ✅ Local test passed!                     │
│                          │                                          │
└──────────────────────────┼──────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│              Step 8: Trigger GitHub Actions Pipeline               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  From Your Laptop:                                                 │
│  ┌────────────────────────────────────────────────────┐            │
│  │ git add .                                          │            │
│  │ git commit -m "test: trigger pipeline"            │            │
│  │ git push origin main                               │            │
│  └────────────────────────────────────────────────────┘            │
│                          │                                          │
│                          ▼                                          │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │              GITHUB ACTIONS PIPELINE                        │  │
│  │  (Runs automatically on push to main)                       │  │
│  │                                                              │  │
│  │  ┌─────────────────────────────────────────────────────┐   │  │
│  │  │ JOB 1: train-and-attest (~5 min)                   │   │  │
│  │  │  • Checkout code from GitHub                       │   │  │
│  │  │  • Setup Python 3.11                               │   │  │
│  │  │  • Install dependencies (pip install -r req...)    │   │  │
│  │  │  • Install Cosign                                  │   │  │
│  │  │  • Train model: python src/train_model.py          │   │  │
│  │  │  • Generate SBOMs: python src/generate_sbom.py     │   │  │
│  │  │  • Sign with Cosign (KEYLESS via GitHub OIDC)     │   │  │
│  │  │  • Create SLSA provenance attestation             │   │  │
│  │  │  • Upload artifacts for next jobs                 │   │  │
│  │  └─────────────────────────────────────────────────────┘   │  │
│  │                          │                                  │  │
│  │                          ▼                                  │  │
│  │  ┌─────────────────────────────────────────────────────┐   │  │
│  │  │ JOB 2: security-scan (~3 min)                      │   │  │
│  │  │  • Download artifacts from Job 1                   │   │  │
│  │  │  • Scan dependencies: pip-audit                    │   │  │
│  │  │  • Scan SBOMs: grype (vulnerability scanner)       │   │  │
│  │  │  • Generate vulnerability report                   │   │  │
│  │  │  • Upload security reports                         │   │  │
│  │  └─────────────────────────────────────────────────────┘   │  │
│  │                          │                                  │  │
│  │                          ▼                                  │  │
│  │  ┌─────────────────────────────────────────────────────┐   │  │
│  │  │ JOB 3: policy-gate (~1 min)                        │   │  │
│  │  │  • Download artifacts                              │   │  │
│  │  │  • Setup OPA                                       │   │  │
│  │  │  • Evaluate policy: python policies/test_policy.py │   │  │
│  │  │  • ✓ Model is signed                               │   │  │
│  │  │  • ✓ SBOMs present                                 │   │  │
│  │  │  • ✓ SLSA provenance valid                         │   │  │
│  │  │  • ✓ Quality threshold met                         │   │  │
│  │  │  • ❌ FAIL pipeline if policy violations           │   │  │
│  │  └─────────────────────────────────────────────────────┘   │  │
│  │                          │                                  │  │
│  │                          ▼                                  │  │
│  │  ┌─────────────────────────────────────────────────────┐   │  │
│  │  │ JOB 4: build-container (~4 min)                    │   │  │
│  │  │  • Download model artifacts                        │   │  │
│  │  │  • Setup Docker Buildx                             │   │  │
│  │  │  • Authenticate to AWS (OIDC - no passwords!)      │   │  │
│  │  │  • Login to ECR                                    │   │  │
│  │  │  • Build Docker image:                             │   │  │
│  │  │    FROM python:3.11-slim                           │   │  │
│  │  │    COPY artifacts/model.pkl /app/                  │   │  │
│  │  │    COPY src/model_server.py /app/                  │   │  │
│  │  │    CMD ["python", "model_server.py"]               │   │  │
│  │  │  • Tag: 050083686295.dkr.ecr.../model-server:sha  │   │  │
│  │  │  • Push to ECR                                     │   │  │
│  │  │  • Sign image with Cosign (keyless)               │   │  │
│  │  │  • Attach SBOM as attestation                      │   │  │
│  │  │  • Verify signature                                │   │  │
│  │  └─────────────────────────────────────────────────────┘   │  │
│  │                          │                                  │  │
│  │                          ▼                                  │  │
│  │  ┌─────────────────────────────────────────────────────┐   │  │
│  │  │ JOB 5: deploy-staging (~3 min)                     │   │  │
│  │  │  • Authenticate to AWS (OIDC)                      │   │  │
│  │  │  • Configure kubectl for EKS                       │   │  │
│  │  │  • Update deployment YAML with new image          │   │  │
│  │  │  • kubectl apply -f k8s/deployment.yaml            │   │  │
│  │  │  • Wait for rollout to complete                    │   │  │
│  │  │  • Verify deployment health                        │   │  │
│  │  └─────────────────────────────────────────────────────┘   │  │
│  │                          │                                  │  │
│  └──────────────────────────┼───────────────────────────────────┘  │
│                             │                                       │
│                             ▼                                       │
│            ┌────────────────────────────────────┐                  │
│            │  Pipeline Result: ✅ SUCCESS        │                  │
│            └────────────────────────────────────┘                  │
│                             │                                       │
└─────────────────────────────┼───────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    AWS EKS (Deployment)                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  What Happens During Deployment:                                   │
│                                                                     │
│  1. Kubernetes receives deployment request                         │
│     kubectl apply -f deployment.yaml                               │
│                                                                     │
│  2. Kyverno intercepts (admission webhook)                         │
│     ┌────────────────────────────────────────────┐                 │
│     │ Kyverno Policy Check:                      │                 │
│     │ • Is image signed? ✓                       │                 │
│     │ • Has SLSA provenance? ✓                   │                 │
│     │ • Has SBOM attestation? ✓                  │                 │
│     │ • Correct builder (github-actions)? ✓      │                 │
│     │ • Required labels present? ✓               │                 │
│     │                                            │                 │
│     │ Result: ✅ ALLOW deployment                │                 │
│     └────────────────────────────────────────────┘                 │
│                                                                     │
│  3. Kubernetes creates pods                                        │
│     ┌─────────────────────────────────────────────────────────┐   │
│     │  Pod: model-server-abc123                               │   │
│     │  ┌───────────────────────────────────────────────────┐  │   │
│     │  │ Container: model-server                           │  │   │
│     │  │                                                    │  │   │
│     │  │ 1. Pull image from ECR:                           │  │   │
│     │  │    050083686295.dkr.ecr.../model-server:sha       │  │   │
│     │  │                                                    │  │   │
│     │  │ 2. Start model server:                            │  │   │
│     │  │    python src/model_server.py                     │  │   │
│     │  │                                                    │  │   │
│     │  │ 3. Server verifies model signature on startup:    │  │   │
│     │  │    - Loads cosign public key from K8s secret      │  │   │
│     │  │    - Verifies model.pkl signature                 │  │   │
│     │  │    - Validates SLSA provenance                    │  │   │
│     │  │    - ✅ Signature valid → Continue                │  │   │
│     │  │    - ❌ Signature invalid → Crash (fail-safe)     │  │   │
│     │  │                                                    │  │   │
│     │  │ 4. Expose API endpoints:                          │  │   │
│     │  │    GET  /health       - Health check              │  │   │
│     │  │    POST /predict      - Make predictions          │  │   │
│     │  │    GET  /attestations - View provenance           │  │   │
│     │  │                                                    │  │   │
│     │  │ 5. Ready to serve traffic! 🚀                     │  │   │
│     │  └───────────────────────────────────────────────────┘  │   │
│     └─────────────────────────────────────────────────────────┘   │
│                                                                     │
│  4. Service exposes pods                                           │
│     ┌────────────────────────────────────────────┐                 │
│     │ Service: model-server                      │                 │
│     │ Type: ClusterIP                            │                 │
│     │ Port: 80 → Pod:8080                        │                 │
│     │                                            │                 │
│     │ Routes traffic to healthy pods:            │                 │
│     │ • model-server-abc123 ✓                    │                 │
│     │ • model-server-def456 ✓                    │                 │
│     └────────────────────────────────────────────┘                 │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 Step 9: Verify & Test                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  From Your Laptop:                                                 │
│                                                                     │
│  1. Check deployment status                                        │
│     ┌────────────────────────────────────────────────┐             │
│     │ kubectl get deployments -n ml-staging          │             │
│     │                                                │             │
│     │ NAME           READY   UP-TO-DATE   AVAILABLE  │             │
│     │ model-server   2/2     2            2          │             │
│     └────────────────────────────────────────────────┘             │
│                                                                     │
│  2. Check pods                                                     │
│     ┌────────────────────────────────────────────────┐             │
│     │ kubectl get pods -n ml-staging                 │             │
│     │                                                │             │
│     │ NAME                    READY   STATUS         │             │
│     │ model-server-abc123     1/1     Running ✓      │             │
│     │ model-server-def456     1/1     Running ✓      │             │
│     └────────────────────────────────────────────────┘             │
│                                                                     │
│  3. Check ECR images                                               │
│     ┌────────────────────────────────────────────────┐             │
│     │ aws ecr describe-images                        │             │
│     │                                                │             │
│     │ IMAGE TAG              PUSHED AT               │             │
│     │ main-sha-abc123        2026-08-05 14:30       │             │
│     │ latest                 2026-08-05 14:30       │             │
│     └────────────────────────────────────────────────┘             │
│                                                                     │
│  4. Test the API                                                   │
│     ┌────────────────────────────────────────────────────────┐    │
│     │ # Port-forward to access locally                       │    │
│     │ kubectl port-forward -n ml-staging \                   │    │
│     │   svc/model-server 8080:80                             │    │
│     │                                                         │    │
│     │ # Test health endpoint                                 │    │
│     │ curl http://localhost:8080/health                      │    │
│     │ → {"status": "healthy"}                                │    │
│     │                                                         │    │
│     │ # Make a prediction                                    │    │
│     │ curl -X POST http://localhost:8080/predict \           │    │
│     │   -H "Content-Type: application/json" \                │    │
│     │   -d '{"features": [5.1, 3.5, 1.4, 0.2]}'              │    │
│     │                                                         │    │
│     │ → {                                                    │    │
│     │     "prediction": 0,                                   │    │
│     │     "model_version": "1.0.0",                          │    │
│     │     "model_hash": "abc123...",                         │    │
│     │     "verified": true  ← Signature verified! 🔐         │    │
│     │   }                                                    │    │
│     │                                                         │    │
│     │ # View provenance                                      │    │
│     │ curl http://localhost:8080/attestations                │    │
│     │ → Shows who built it, when, where, how                 │    │
│     └────────────────────────────────────────────────────────┘    │
│                                                                     │
│  ✅ Everything works!                                              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘


═══════════════════════════════════════════════════════════════════════
                         SUCCESS! 🎉
═══════════════════════════════════════════════════════════════════════

What you've built:

✅ Kubernetes cluster on AWS (EKS)
✅ Automated CI/CD pipeline (GitHub Actions)
✅ Cryptographic signing (Cosign)
✅ Supply chain security (SLSA Level 3)
✅ Policy enforcement (Kyverno)
✅ Zero-trust verification (at every stage)
✅ Complete observability (SBOMs, provenance)

Security guarantees:

🔐 Only signed models can be deployed
🔐 Tampering is detected immediately
🔐 Full audit trail (who, what, when, where)
🔐 Vulnerability tracking (SBOMs)
🔐 Runtime verification (server checks signature)

═══════════════════════════════════════════════════════════════════════

Next: Customize for your own models!
      Replace src/train_model.py with your actual ML code.
```

## 🎯 Key Takeaways

1. **Local first**: Always test locally before pushing to GitHub
2. **Fail-safe**: Each stage can reject bad artifacts
3. **Zero-trust**: Verify at every step, never assume
4. **Automated**: Push code → everything happens automatically
5. **Observable**: Full visibility into the supply chain

## 🔄 The Security Chain

```
Train → Sign → Verify → Build → Sign → Verify → Deploy → Verify
  ✓      ✓      ✓        ✓      ✓      ✓        ✓      ✓
```

If ANY step fails, the chain breaks and deployment stops. This is **supply chain security**!
