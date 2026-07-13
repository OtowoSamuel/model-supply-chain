# Quick Start Guide

Get up and running with model supply chain security in 5 minutes.

## Prerequisites

Install required tools:

```bash
# macOS
brew install cosign opa python@3.11

# Linux (Debian/Ubuntu)
# Install cosign
curl -sLO https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign

# Install OPA
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
sudo mv opa /usr/local/bin/
sudo chmod +x /usr/local/bin/opa
```

## Option 1: Automated Demo (Recommended)

Run the full pipeline with one command:

```bash
chmod +x scripts/e2e-demo.sh
./scripts/e2e-demo.sh
```

This will:
1. ✅ Install dependencies
2. ✅ Train a model with provenance
3. ✅ Generate SBOMs
4. ✅ Sign all artifacts
5. ✅ Verify signatures
6. ✅ Evaluate OPA policy

## Option 2: Step-by-Step

### 1. Install Python Dependencies

```bash
# Use Python 3.11 or 3.12 (avoid 3.14 - compatibility issues)
python3.11 -m pip install -r requirements.txt
# or
python3.12 -m pip install -r requirements.txt
```

### 2. Train Model

```bash
python src/train_model.py
```

**Output:**
- `artifacts/model.pkl` - Trained model
- `artifacts/metadata.json` - Model metadata
- `artifacts/attestations/provenance.json` - SLSA provenance

### 3. Generate SBOMs

```bash
python src/generate_sbom.py artifacts/metadata.json
```

**Output:**
- `artifacts/sbom/code-sbom.json` - Python dependencies
- `artifacts/sbom/model-sbom.json` - Model metadata

### 4. Sign Artifacts

```bash
python src/sign_artifact.py artifacts
```

**Output:**
- `keys/cosign.key` - Private key (keep secret!)
- `keys/cosign.pub` - Public key (distribute)
- `artifacts/model.pkl.sig` - Model signature
- `artifacts/sbom/*.sig` - SBOM signatures

### 5. Verify Artifacts

```bash
chmod +x examples/verify_model.py
python examples/verify_model.py artifacts keys/cosign.pub
```

Should show: ✅ All verification checks passed!

### 6. Test OPA Policy

```bash
python policies/test_policy.py artifacts
```

Should show: ✅ Policy evaluation: ALLOWED

### 7. Start Model Server

```bash
python src/model_server.py
```

Server starts on http://localhost:8080

### 8. Test API

In another terminal:

```bash
chmod +x examples/test_api.sh
./examples/test_api.sh
```

Or manually:

```bash
# Health check
curl http://localhost:8080/health

# Make prediction
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [5.1, 3.5, 1.4, 0.2]}'

# View provenance
curl http://localhost:8080/attestations
```

## Option 3: Using Make

```bash
# Full pipeline
make all

# Individual steps
make install      # Install dependencies
make train        # Train model
make sign         # Sign artifacts
make verify       # Verify signatures
make policy       # Test OPA policy
make serve        # Start server
```

## Docker Deployment

### Build Container

```bash
make docker
# or
docker build -t model-server:latest .
```

### Run Container

```bash
make docker-run
# or
docker run -p 8080:8080 model-server:latest
```

### Test

```bash
curl http://localhost:8080/health
```

## Kubernetes Deployment

### Prerequisites

1. Install Kyverno:

```bash
kubectl create -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml
```

2. Deploy policies:

```bash
kubectl apply -f k8s/kyverno-policy.yaml
```

3. Create public key secret:

```bash
kubectl create secret generic cosign-public-key \
  --from-file=cosign.pub=keys/cosign.pub \
  -n ml-staging
```

### Deploy Model Server

```bash
kubectl apply -f k8s/deployment.yaml
```

Kyverno will automatically verify signatures before allowing deployment.

## Troubleshooting

### "cosign not found"

Install cosign: https://docs.sigstore.dev/cosign/installation/

### "Model signature verification failed"

Ensure you're using the correct public key:

```bash
cosign verify-blob artifacts/model.pkl \
  --key keys/cosign.pub \
  --signature artifacts/model.pkl.sig
```

### "OPA policy evaluation failed"

Check violations:

```bash
opa eval \
  --data policies/model_deployment.rego \
  --input /tmp/opa_input.json \
  --format pretty \
  "data.model.deployment.violations"
```

### Model accuracy below threshold

The default policy requires ≥85% accuracy. To adjust:

Edit `policies/model_deployment.rego`:

```rego
meets_quality_threshold if {
    input.metadata.accuracy >= 0.80  # Lower threshold
}
```

## Next Steps

1. **Read the docs**: See [ARCHITECTURE.md](ARCHITECTURE.md) for design details
2. **Review security**: Read [SECURITY.md](SECURITY.md) for threat model
3. **Customize**: Adapt for your model type (TensorFlow, PyTorch, etc.)
4. **Set up CI/CD**: Use `.github/workflows/model-pipeline.yml` as template

## Support

For questions or issues, see:
- GitHub Issues: [Report a bug]
- Documentation: [ARCHITECTURE.md](ARCHITECTURE.md)
- Security: [SECURITY.md](SECURITY.md)
