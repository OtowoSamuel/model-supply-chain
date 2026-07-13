# Model Supply Chain Security Architecture

## Overview

This project implements a comprehensive **model supply chain security** solution that treats ML models like container images with full provenance tracking, cryptographic signing, and policy-based deployment gates.

## The Problem

Traditional ML pipelines lack the security controls common in software supply chains:
- No cryptographic verification of model artifacts
- Missing visibility into training data and dependencies
- No standardized provenance tracking
- Weak deployment gates that allow unsigned/unverified models
- No SBOM (Software Bill of Materials) for ML artifacts

This creates risks:
- **Model Tampering**: Attackers can replace models with backdoored versions
- **Supply Chain Attacks**: Poisoned dependencies in training pipeline
- **Compliance Gaps**: Inability to prove model lineage and security posture
- **Drift Detection**: No way to detect unauthorized model changes

## The Solution

Our architecture applies supply chain security principles to ML:

### 1. **Artifact Signing with Cosign**

Every model artifact is cryptographically signed using [Sigstore Cosign](https://github.com/sigstore/cosign):

- **Keyless signing** with OIDC for CI/CD (no key management burden)
- **Key-based signing** for air-gapped environments
- **Transparency log** via Rekor for non-repudiation
- **Signature verification** at runtime before serving

```bash
# Sign model
cosign sign-blob artifacts/model.pkl --bundle model.pkl.bundle

# Verify at deployment
cosign verify-blob artifacts/model.pkl --bundle model.pkl.bundle
```

### 2. **Comprehensive SBOMs**

We generate **three types** of SBOMs in CycloneDX format:

a) **Code SBOM**: Python dependencies from requirements.txt
b) **Model SBOM**: Training data, framework, model metadata
c) **Container SBOM**: Full container image dependencies

SBOMs enable:
- Vulnerability scanning (Grype, Trivy)
- License compliance checking
- Dependency tracking for audit trails

### 3. **SLSA Provenance**

[SLSA (Supply-chain Levels for Software Artifacts)](https://slsa.dev/) provenance tracks:

- **Builder identity**: Where was the model trained?
- **Build parameters**: Hyperparameters, dataset versions
- **Materials**: Source code, dependencies used
- **Timestamps**: When training started/finished
- **Reproducibility metadata**: Can this be rebuilt?

Provenance is captured as an [in-toto attestation](https://github.com/in-toto/attestation) and signed:

```json
{
  "_type": "https://in-toto.io/Statement/v0.1",
  "predicateType": "https://slsa.dev/provenance/v0.2",
  "subject": [{"name": "model.pkl", "digest": {"sha256": "..."}}],
  "predicate": {
    "buildType": "...",
    "builder": {"id": "github-actions"},
    "materials": [...]
  }
}
```

### 4. **Policy-as-Code Enforcement**

Two-layer policy enforcement:

#### a) OPA (Open Policy Agent)
Pre-deployment policy evaluation written in Rego:

```rego
# policies/model_deployment.rego
allow if {
    has_valid_signature
    has_valid_sbom
    has_slsa_provenance
    meets_quality_threshold
    no_critical_vulnerabilities
}
```

Policies check:
- ✅ Artifact is signed
- ✅ SBOMs are present and valid
- ✅ SLSA provenance exists
- ✅ Model accuracy meets threshold (e.g., >85%)
- ✅ No critical CVEs in dependencies
- ✅ Trusted builder (e.g., GitHub Actions)

#### b) Kyverno (Kubernetes)
Runtime policy enforcement at the cluster level:

- Verifies image signatures on pod admission
- Checks SLSA attestations are present
- Enforces required labels/annotations
- Blocks unsigned or unattested images

```yaml
verifyImages:
  - imageReferences: ["ghcr.io/*/model-server*"]
    attestations:
      - predicateType: https://slsa.dev/provenance/v0.2
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    MODEL TRAINING PIPELINE                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. Train Model (train_model.py)                                │
│     └─> Generates: model.pkl + metadata.json + provenance.json │
│                                                                   │
│  2. Generate SBOMs (generate_sbom.py)                           │
│     ├─> Code SBOM (CycloneDX)                                   │
│     └─> Model SBOM (CycloneDX)                                  │
│                                                                   │
│  3. Sign Artifacts (sign_artifact.py / cosign)                  │
│     ├─> Sign model: model.pkl.sig                               │
│     ├─> Sign SBOMs: *.sbom.sig                                  │
│     └─> Attest provenance: model.pkl.att                        │
│                                                                   │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    POLICY GATE (OPA)                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Evaluate: policies/model_deployment.rego                       │
│                                                                   │
│  ✓ Signature valid?                                             │
│  ✓ SBOMs present?                                               │
│  ✓ SLSA provenance valid?                                       │
│  ✓ Quality threshold met?                                       │
│  ✓ No critical CVEs?                                            │
│                                                                   │
│  Decision: ALLOW / DENY                                         │
│                                                                   │
└───────────────────────┬─────────────────────────────────────────┘
                        │ ALLOW
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                CONTAINER BUILD & SIGN                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. Build container with model artifacts                        │
│  2. Sign container image with cosign                            │
│  3. Attach SBOM as attestation                                  │
│  4. Push to registry (ghcr.io)                                  │
│                                                                   │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│            KUBERNETES DEPLOYMENT (Kyverno)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. Pod admission webhook intercepts                            │
│  2. Kyverno verifies:                                           │
│     ├─> Image signature (cosign)                                │
│     ├─> SLSA provenance attestation                             │
│     └─> Required metadata labels                                │
│                                                                   │
│  3. If valid: Deploy model-server pod                           │
│     If invalid: REJECT deployment                               │
│                                                                   │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                   MODEL SERVING (Runtime)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  model_server.py:                                               │
│                                                                   │
│  On startup:                                                    │
│    1. Verify model signature with cosign                        │
│    2. Validate SLSA provenance structure                        │
│    3. Load model ONLY if verified                               │
│                                                                   │
│  Endpoints:                                                     │
│    GET  /health       - Health + verification status            │
│    POST /predict      - Serve predictions (verified models only)│
│    GET  /attestations - Expose provenance for audit             │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Security Properties

### SLSA Level Achieved

This implementation targets **SLSA Build Level 3**:

- ✅ **L1**: Provenance exists and is signed
- ✅ **L2**: Hosted build platform (GitHub Actions), signed provenance
- ✅ **L3**: Hardened build platform, non-falsifiable provenance

### Threat Model Coverage

| Threat | Mitigation |
|--------|-----------|
| **Model Tampering** | Cosign signatures detect unauthorized changes |
| **Supply Chain Attack** | SBOM + vulnerability scanning catch malicious deps |
| **Backdoored Models** | Provenance tracks builder identity + materials |
| **Insider Threat** | Transparency log (Rekor) provides audit trail |
| **Deployment Drift** | Runtime verification prevents serving unsigned models |
| **Compliance Violations** | Policy-as-code enforces requirements consistently |

## Standards Alignment

- **SLSA**: Supply-chain Levels for Software Artifacts (v0.2)
- **in-toto**: Attestation framework for provenance
- **CycloneDX**: SBOM format (OWASP standard)
- **Sigstore**: Keyless signing infrastructure
- **MITRE ATLAS**: ML threat framework (coverage for AML.T0000 series)
- **OWASP ML Top 10**: Addresses ML03 (Model Poisoning) and ML05 (Supply Chain)

## Components

### Core Scripts

| Script | Purpose |
|--------|---------|
| `src/train_model.py` | Train model with provenance tracking |
| `src/generate_sbom.py` | Generate code + model SBOMs |
| `src/sign_artifact.py` | Sign artifacts with cosign |
| `src/model_server.py` | Serve model with runtime verification |
| `policies/test_policy.py` | OPA policy evaluation |

### Policies

- `policies/model_deployment.rego`: OPA deployment policy
- `k8s/kyverno-policy.yaml`: Kubernetes admission control

### Infrastructure

- `Dockerfile`: Secure container with cosign verification
- `k8s/deployment.yaml`: Hardened Kubernetes manifests
- `.github/workflows/model-pipeline.yml`: Full CI/CD pipeline

## Why This Matters

This gap is **critical** in production ML:

1. **Regulatory Pressure**: EU AI Act, NIST AI RMF require supply chain controls
2. **High-Profile Attacks**: Poisoned models (BadNets), trojaned datasets
3. **DevSecOps Parity**: Software has this; ML doesn't (yet)
4. **Zero Trust ML**: "Never trust, always verify" for models

## References

- [SLSA](https://slsa.dev/)
- [Sigstore Cosign](https://github.com/sigstore/cosign)
- [in-toto Attestations](https://github.com/in-toto/attestation)
- [MITRE ATLAS](https://atlas.mitre.org/)
- [OWASP ML Security](https://owasp.org/www-project-machine-learning-security-top-10/)
- [CycloneDX SBOM](https://cyclonedx.org/)
- [Kyverno](https://kyverno.io/)
