# Model Supply Chain Security 🔐

> **Production-grade supply chain security for ML models**: Cryptographic signing, SBOMs, SLSA provenance, and policy-based deployment gates.

[![SLSA Level](https://img.shields.io/badge/SLSA-Level%203-brightgreen)](https://slsa.dev/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## 🎯 The Problem

Most ML pipelines lack basic supply chain security:
- ❌ No cryptographic verification of model artifacts
- ❌ No visibility into training dependencies
- ❌ No provenance tracking (who trained this model?)
- ❌ Weak deployment gates allowing unsigned models
- ❌ No SBOM for vulnerability scanning

**This is the "model supply chain security" gap** that MITRE ATLAS and OWASP ML Security highlight but few have solved publicly.

## 💡 The Solution

This project demonstrates **end-to-end supply chain security for ML models**:

1. **🔏 Artifact Signing**: Sign models with [Cosign](https://github.com/sigstore/cosign) (keyless or key-based)
2. **📦 SBOMs**: Generate Software Bill of Materials for code, model, and container
3. **📜 SLSA Provenance**: Track build metadata with [in-toto attestations](https://github.com/in-toto/attestation)
4. **🚦 Policy Gates**: Enforce security requirements with OPA and Kyverno
5. **🔍 Runtime Verification**: Reject unsigned/unattested models at serving time

## 🏗️ Architecture

```
Train Model → Generate SBOMs → Sign Artifacts → Policy Gate (OPA) 
   → Build Container → Sign Image → Deploy (Kyverno) → Serve (Verified)
```

See [ARCHITECTURE.md](docs/technical/ARCHITECTURE.md) for detailed design and threat model.

## 🚀 Quick Start

### Prerequisites

```bash
# Install required tools
brew install cosign opa kubernetes-cli  # macOS
# or use package manager of choice

# Use Python 3.11 or 3.12 (NOT 3.14 - has compatibility issues)
python3.11 -m pip install -r requirements.txt
```

### 1. Train Model with Provenance

```bash
# Train model and generate metadata + provenance
python src/train_model.py

# Output:
# ✅ artifacts/model.pkl
# ✅ artifacts/metadata.json
# ✅ artifacts/attestations/provenance.json
```

### 2. Generate SBOMs

```bash
# Generate code and model SBOMs
python src/generate_sbom.py artifacts/metadata.json

# Output:
# ✅ artifacts/sbom/code-sbom.json (CycloneDX)
# ✅ artifacts/sbom/model-sbom.json (CycloneDX)
```

### 3. Sign Artifacts

```bash
# Option A: Key-based signing (local dev)
python src/sign_artifact.py artifacts

# Option B: Keyless signing (CI/CD)
python src/sign_artifact.py artifacts --keyless

# Output:
# ✅ artifacts/model.pkl.sig
# ✅ artifacts/sbom/*.sig
# ✅ keys/cosign.key + cosign.pub (key-based only)
```

### 4. Evaluate Policies

```bash
# Test OPA deployment policy
python policies/test_policy.py artifacts

# Output:
# ✅ Policy evaluation: ALLOWED
# (or ❌ with violation details)
```

### 5. Serve Model

```bash
# Start server with signature verification
python src/model_server.py

# Server endpoints:
# GET  /health       - Health check
# POST /predict      - Make predictions
# GET  /attestations - View provenance
```

### 6. Test Predictions

```bash
# Make a prediction
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [5.1, 3.5, 1.4, 0.2]}'

# Response:
# {"prediction": 0, "model_version": "1.0.0", "model_hash": "abc123..."}
```

## 📋 What Gets Generated

```
artifacts/
├── model.pkl                       # Trained model
├── model.pkl.sig                   # Cosign signature
├── model.pkl.bundle                # Cosign bundle (keyless)
├── metadata.json                   # Model metadata
├── sbom/
│   ├── code-sbom.json             # Python dependencies SBOM
│   ├── code-sbom.json.sig         # Signed
│   ├── model-sbom.json            # Model artifact SBOM
│   └── model-sbom.json.sig        # Signed
└── attestations/
    ├── provenance.json            # SLSA provenance
    └── provenance.json.sig        # Signed

keys/
├── cosign.key                      # Private signing key
└── cosign.pub                      # Public verification key
```

## 🔒 Security Features

### OPA Policy Checks

The deployment policy (`policies/model_deployment.rego`) enforces:

- ✅ Model artifact is signed with Cosign
- ✅ Code and model SBOMs are present
- ✅ SLSA provenance attestation exists
- ✅ Model accuracy meets threshold (e.g., ≥85%)
- ✅ No critical CVEs in dependencies
- ✅ Builder is trusted (e.g., GitHub Actions)

### Kyverno Kubernetes Policy

The Kyverno policy (`k8s/kyverno-policy.yaml`) enforces:

- ✅ Container images must be signed
- ✅ SLSA provenance must be attached to images
- ✅ Required metadata labels present
- ✅ Only allow deployments to ml-production namespace with valid attestations

### Runtime Verification

The model server (`src/model_server.py`):

- ✅ Verifies Cosign signature before loading model
- ✅ Validates SLSA provenance structure
- ✅ Rejects serving unsigned/unverified models
- ✅ Exposes provenance via API for audit

## 🚢 CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/model-pipeline.yml`) implements the full pipeline:

```yaml
1. train-and-attest:
   - Train model with provenance tracking
   - Generate SBOMs (code, model, container)
   - Sign artifacts with Cosign keyless
   - Create SLSA attestations

2. security-scan:
   - Scan dependencies with pip-audit
   - Scan SBOMs with Grype
   - Generate vulnerability reports

3. policy-gate:
   - Evaluate OPA policy
   - Block if policy violations detected

4. build-container:
   - Build Docker image
   - Sign image with Cosign
   - Attach SBOM as attestation
   - Push to registry

5. deploy-staging:
   - Deploy to Kubernetes
   - Kyverno verifies signatures at admission
```

## 🎓 Educational Value

This project addresses a **real industry gap**:

- **MITRE ATLAS**: Covers adversarial ML tactics (model poisoning, backdoors)
- **OWASP ML Top 10**: Addresses ML03 (Model Poisoning) and ML05 (Supply Chain)
- **SLSA for ML**: Extends software supply chain security to ML artifacts
- **Zero Trust ML**: "Never trust, always verify" for models

### Key Learnings

1. **Models are artifacts**: Treat them like containers with signing and provenance
2. **SBOMs for ML**: Track both code dependencies AND model metadata
3. **Policy as Code**: Enforce security requirements consistently
4. **Runtime verification**: Don't trust; verify at serving time

## 📚 Documentation

**Getting Started:**
- [START_HERE.md](docs/getting-started/START_HERE.md) - Complete beginner guide
- [TLDR.md](docs/getting-started/TLDR.md) - 2-minute overview
- [QUICKSTART.md](docs/getting-started/QUICKSTART.md) - 5-minute guide

**Technical Details:**
- [ARCHITECTURE.md](docs/technical/ARCHITECTURE.md) - Design and threat model
- [SECURITY.md](docs/technical/SECURITY.md) - Security policy
- [BEST_PRACTICES_REVIEW.md](docs/technical/BEST_PRACTICES_REVIEW.md) - Standards compliance

**Reference:**
- [CHEATSHEET.md](docs/reference/CHEATSHEET.md) - All commands
- [PROJECT_SUMMARY.md](docs/reference/PROJECT_SUMMARY.md) - Project overview
- [BLOG_POST.md](docs/BLOG_POST.md) - Publication-ready writeup
- [FAQ.md](docs/FAQ.md) - Common questions

**External Resources:**
- [SLSA](https://slsa.dev/) - Supply-chain Levels for Software Artifacts
- [Sigstore Cosign](https://github.com/sigstore/cosign) - Artifact signing
- [MITRE ATLAS](https://atlas.mitre.org/) - Adversarial ML threat matrix
- [OWASP ML Security](https://owasp.org/www-project-machine-learning-security-top-10/)

## 🛠️ Customization

### Change Model Type

Edit `src/train_model.py` to use your model:

```python
# Replace with your model
model = YourModel(...)
model.fit(X_train, y_train)
```

### Adjust Policy Thresholds

Edit `policies/model_deployment.rego`:

```rego
meets_quality_threshold if {
    input.metadata.accuracy >= 0.90  # Increase threshold
}
```

### Add Custom Attestations

Extend `src/train_model.py` to add custom metadata:

```python
metadata["custom_field"] = "value"
provenance_tracker.set_parameters({"custom": "param"})
```

## 🤝 Contributing

Contributions welcome! This is meant to be educational and practical. Areas for improvement:

- Support for TensorFlow, PyTorch models
- Integration with MLflow, Weights & Biases
- SLSA Level 4 (hermetic builds)
- Model drift detection
- Federated learning provenance

## 📄 License

MIT License - see [LICENSE](LICENSE)

## 🙏 Acknowledgments

Built on the shoulders of giants:
- Sigstore team for Cosign
- SLSA and in-toto communities
- MITRE ATLAS and OWASP ML Security projects
- Open Policy Agent and Kyverno maintainers

---

**⭐ If you find this useful, please star the repo and share!** This gap needs more attention in the ML community.
