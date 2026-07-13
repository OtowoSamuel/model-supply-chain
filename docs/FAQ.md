# Frequently Asked Questions

## General Questions

### What is model supply chain security?

Model supply chain security applies software supply chain security principles to ML artifacts. Just like container images are signed and verified, ML models should be:
- Cryptographically signed
- Accompanied by SBOMs (Software Bill of Materials)
- Tracked with provenance (who, what, when, where, how)
- Gated by policies before deployment

### Why do I need this?

Traditional MLOps doesn't provide:
- **Verification**: No way to prove a model wasn't tampered with
- **Auditability**: Can't prove which model version is deployed
- **Compliance**: Can't meet regulatory requirements (EU AI Act, etc.)
- **Threat mitigation**: Vulnerable to supply chain attacks

### How is this different from MLflow/SageMaker?

This is **complementary**, not a replacement:
- MLflow/SageMaker: Experiment tracking, model registry, deployment
- This project: Supply chain security, signing, provenance, verification

Use both: Track experiments with MLflow, then sign and verify with this project.

### Is this production-ready?

The **architecture and approach** are production-ready. The **code is a reference implementation** meant for:
1. Understanding the concepts
2. Adapting to your environment
3. Building on top of

For production, you'll want to:
- Add comprehensive tests
- Integrate with your MLOps platform
- Customize policies for your requirements
- Set up monitoring and alerting

## Technical Questions

### Do I need to use Kubernetes?

No. The components work independently:
- **Training + signing**: Works anywhere (laptop, CI/CD, cloud)
- **OPA policy**: Can run in Lambda, Cloud Functions, etc.
- **Kyverno**: Only needed for Kubernetes admission control

### What about keyless vs key-based signing?

**Keyless (recommended for CI/CD)**:
- Uses OIDC tokens (GitHub Actions, etc.)
- No key management
- Signatures logged to Rekor transparency log
- Requires internet access

**Key-based (recommended for air-gapped)**:
- You manage private keys
- Works offline
- More control but more complexity

### Can I use this with TensorFlow/PyTorch?

Yes! The core concepts apply to any framework. You'll need to:
1. Adapt `train_model.py` to your framework
2. Update SBOM generator for framework-specific metadata
3. Adjust model loading in `model_server.py`

See [examples/](../examples/) for framework-specific guides (coming soon).

### How do I integrate with existing CI/CD?

The GitHub Actions workflow (`.github/workflows/model-pipeline.yml`) is a template. Adapt for:
- **GitLab CI**: Use cosign in GitLab runners
- **Jenkins**: Run scripts in pipeline stages
- **Azure DevOps**: Use cosign tasks
- **CircleCI**: Similar to GitHub Actions

Core steps are the same: train → sign → policy → deploy.

### What's the performance impact?

Minimal:
- **Build time**: +20-50 seconds for SBOM + signing
- **Runtime**: +1-2 seconds for verification (one-time at load)
- **Storage**: +0.1% (signatures and SBOMs are tiny)

### Can I use this without OPA?

Yes. OPA is optional but recommended. Without OPA:
- Still sign artifacts with Cosign
- Still generate SBOMs
- Still track provenance
- Just skip the policy evaluation step

For basic checks, you can use shell scripts instead of OPA.

### How do I handle model updates?

Each model version gets:
- New signature
- New SBOM
- New provenance

Version in metadata:
```json
{
  "version": "2.0.0",
  "trained_at": "2024-01-15T10:00:00Z",
  "artifact": {
    "sha256": "new_hash..."
  }
}
```

### What about A/B testing?

Sign both models:
```bash
cosign sign-blob model_a.pkl --key cosign.key
cosign sign-blob model_b.pkl --key cosign.key
```

Policy checks both before deploying to A/B test.

## Security Questions

### Is keyless signing secure?

Yes. Keyless signing with Sigstore:
- Uses short-lived certificates (10 minutes)
- Binds identity to signature (GitHub user/org)
- Logs to transparency log (Rekor)
- Requires OIDC token (can't be forged)

It's **more secure** than key-based for most use cases (no keys to leak).

### What if someone compromises my CI/CD?

Defense in depth:
1. **GitHub Actions**: Attacker needs write access to repo
2. **Rekor log**: Signatures are timestamped and public
3. **OPA policy**: Checks builder identity
4. **Kyverno**: Re-verifies at deployment

Compromise requires multiple failures.

### Can I verify without internet access?

**Key-based**: Yes, works fully offline
**Keyless**: No, requires access to Rekor and Fulcio

For air-gapped: Use key-based signing.

### How do I rotate keys?

For key-based signing:
1. Generate new keypair: `cosign generate-key-pair`
2. Re-sign artifacts with new key
3. Update public key in deployment
4. Retire old key after transition period

For keyless: No rotation needed (ephemeral certificates).

### What about privacy?

SBOMs and provenance may contain sensitive info:
- Dataset names
- Hyperparameters
- Commit messages

Options:
1. **Sanitize**: Remove sensitive fields before signing
2. **Private registry**: Don't publish SBOMs publicly
3. **Encrypted attestations**: Encrypt sensitive provenance data

## Compliance Questions

### Does this meet SLSA requirements?

Yes, for **SLSA Build Level 3**:
- ✅ L1: Provenance generated
- ✅ L2: Signed provenance from hosted build
- ✅ L3: Hardened build, non-falsifiable provenance

L4 (hermetic builds) is future work.

### What about GDPR/data privacy?

This project doesn't handle training data directly. For GDPR:
- Track dataset versions in provenance
- Link to data processing records
- Include privacy metadata in SBOM

### Does this satisfy EU AI Act requirements?

Helps with:
- **Article 11**: Technical documentation requirements
- **Article 60**: Record-keeping obligations
- **Annex IV**: Provenance and traceability

Not a complete solution but provides the infrastructure.

### Can auditors verify claims?

Yes:
1. **Rekor log**: Public record of signatures
2. **SLSA provenance**: Shows exact build process
3. **SBOMs**: Lists all dependencies
4. **OPA policy**: Version-controlled requirements

All artifacts are timestamped and signed.

## Troubleshooting

### "cosign: command not found"

Install Cosign: https://docs.sigstore.dev/cosign/installation/

```bash
# macOS
brew install cosign

# Linux
curl -sLO https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign
```

### "Signature verification failed"

Check:
1. Using correct public key? `ls keys/cosign.pub`
2. Model unchanged since signing? `sha256sum artifacts/model.pkl`
3. Signature file exists? `ls artifacts/model.pkl.sig`

Re-sign if needed:
```bash
python src/sign_artifact.py artifacts
```

### "OPA policy evaluation failed"

Check violations:
```bash
python policies/test_policy.py artifacts
```

Common issues:
- Model accuracy below threshold (default: 85%)
- Missing SBOM files
- Missing signature
- Untrusted builder in provenance

### "ModuleNotFoundError: No module named 'sklearn'"

Install dependencies:
```bash
pip install -r requirements.txt
```

### Docker build fails

Check:
1. Artifacts exist: `ls -la artifacts/`
2. Model trained: `ls -la artifacts/model.pkl`
3. SBOMs generated: `ls -la artifacts/sbom/`

Run full pipeline:
```bash
make all
```

## Advanced Topics

### Can I use custom attestation types?

Yes! Create custom predicates:
```json
{
  "predicateType": "https://yourcompany.com/ml/fairness/v1",
  "predicate": {
    "bias_metrics": {...},
    "fairness_checks": {...}
  }
}
```

Then attest:
```bash
cosign attest-blob model.pkl \
  --predicate custom.json \
  --type https://yourcompany.com/ml/fairness/v1
```

### How do I add custom OPA policies?

Edit `policies/model_deployment.rego`:
```rego
# Custom check: Require specific dataset
requires_approved_dataset if {
    input.metadata.dataset in {
        "approved_dataset_v1",
        "approved_dataset_v2"
    }
}

violations[msg] {
    not requires_approved_dataset
    msg := "Dataset not approved"
}
```

### Can I verify in production continuously?

Yes. Options:
1. **Periodic checks**: Cron job re-verifies signatures
2. **Health endpoint**: Include verification in `/health`
3. **Sidecar**: Run verification sidecar that monitors model files

### How do I handle federated learning?

Track each participant:
```json
{
  "materials": [
    {"uri": "participant:hospital_a", "digest": {...}},
    {"uri": "participant:hospital_b", "digest": {...}}
  ]
}
```

Each participant signs their contribution, final model aggregates attestations.

## Still Have Questions?

- Check [ARCHITECTURE.md](../ARCHITECTURE.md) for design details
- Read [SECURITY.md](../SECURITY.md) for threat model
- Open a GitHub issue
- Join community discussions

## Contributing

Help improve this FAQ! If you had a question not covered here, please submit a PR adding it.
