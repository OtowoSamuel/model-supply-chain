# Command Cheat Sheet

## Installation

```bash
# Use Python 3.11 (NOT 3.14)
python3.11 -m pip install -r requirements.txt

# Install security tools
brew install cosign opa
```

## Quick Demo (Automated)

```bash
# Run everything automatically
./scripts/e2e-demo.sh
```

## Manual Step-by-Step

```bash
# 1. Train model with provenance
python3.11 src/train_model.py

# 2. Generate SBOMs
python3.11 src/generate_sbom.py artifacts/metadata.json

# 3. Sign artifacts (will prompt for password)
python3.11 src/sign_artifact.py artifacts

# 4. Verify signatures
python3.11 examples/verify_model.py artifacts keys/cosign.pub

# 5. Test OPA policy
python3.11 policies/test_policy.py artifacts

# 6. Start model server
python3.11 src/model_server.py
```

## Using Make (Easier)

```bash
make install    # Install dependencies
make train      # Train model
make sign       # Sign artifacts
make verify     # Verify signatures
make policy     # Test policy
make serve      # Start server
make all        # Do everything
```

## Testing the API

```bash
# In terminal 1: Start server
python3.11 src/model_server.py

# In terminal 2: Test endpoints
./examples/test_api.sh

# Or manually:
curl http://localhost:8080/health
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [5.1, 3.5, 1.4, 0.2]}'
```

## Docker

```bash
# Build image
docker build -t model-server:latest .

# Run container
docker run -p 8080:8080 model-server:latest

# Test
curl http://localhost:8080/health
```

## Kubernetes

```bash
# Install Kyverno
kubectl create -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml

# Deploy policies
kubectl apply -f k8s/kyverno-policy.yaml

# Create secret with public key
kubectl create secret generic cosign-public-key \
  --from-file=cosign.pub=keys/cosign.pub \
  -n ml-staging

# Deploy model server
kubectl apply -f k8s/deployment.yaml
```

## Cosign Commands

```bash
# Generate keypair
cosign generate-key-pair

# Sign a file (key-based)
cosign sign-blob model.pkl --key cosign.key --output-signature model.pkl.sig

# Sign a file (keyless)
COSIGN_EXPERIMENTAL=1 cosign sign-blob model.pkl --bundle model.pkl.bundle --yes

# Verify (key-based)
cosign verify-blob model.pkl --key cosign.pub --signature model.pkl.sig

# Create attestation
cosign attest-blob model.pkl \
  --predicate provenance.json \
  --type https://slsa.dev/provenance/v0.2 \
  --key cosign.key
```

## OPA Commands

```bash
# Evaluate policy
opa eval \
  --data policies/model_deployment.rego \
  --input /tmp/opa_input.json \
  --format pretty \
  "data.model.deployment.allow"

# Check violations
opa eval \
  --data policies/model_deployment.rego \
  --input /tmp/opa_input.json \
  --format pretty \
  "data.model.deployment.violations"

# Test policy (easier)
python3.11 policies/test_policy.py artifacts
```

## File Locations

```bash
# Source code
src/train_model.py          # Training
src/generate_sbom.py        # SBOM generation
src/sign_artifact.py        # Signing
src/model_server.py         # Serving

# Generated artifacts
artifacts/model.pkl         # Model
artifacts/model.pkl.sig     # Signature
artifacts/metadata.json     # Metadata
artifacts/sbom/             # SBOMs
artifacts/attestations/     # Provenance

# Keys
keys/cosign.key            # Private key (keep secret!)
keys/cosign.pub            # Public key (distribute)

# Policies
policies/model_deployment.rego    # OPA policy
k8s/kyverno-policy.yaml          # Kyverno policy
```

## Troubleshooting

```bash
# Check Python version
python3.11 --version

# Check tool versions
cosign version
opa version
kubectl version

# List artifacts
ls -la artifacts/
tree artifacts/

# Check signatures exist
ls -la artifacts/*.sig

# Verify manually
cosign verify-blob artifacts/model.pkl \
  --key keys/cosign.pub \
  --signature artifacts/model.pkl.sig

# View SBOM
cat artifacts/sbom/code-sbom.json | python3.11 -m json.tool

# View provenance
cat artifacts/attestations/provenance.json | python3.11 -m json.tool

# Check model server logs
python3.11 src/model_server.py 2>&1 | tee server.log
```

## Cleanup

```bash
# Remove generated files
make clean

# Or manually
rm -rf artifacts/
rm -rf keys/
rm -f /tmp/opa_input.json
```

## Git Commands

```bash
# Initial setup
git init
git add .
git commit -m "feat: initial commit - model supply chain security"

# Push to GitHub
gh repo create model-supply-chain --public --source=. --remote=origin --push

# Or manually
git remote add origin git@github.com:yourusername/model-supply-chain.git
git branch -M main
git push -u origin main
```

## Common Workflows

### Local Development
```bash
make all        # Train, sign, verify
make serve      # Start server
# Test in browser/curl
make clean      # Cleanup
```

### CI/CD Testing
```bash
# Simulate CI environment
export BUILD_ID="test-123"
export BUILDER_ID="local-ci"
export GIT_REPO="https://github.com/user/repo"
export GIT_COMMIT="abc123"

python3.11 src/train_model.py
python3.11 src/generate_sbom.py artifacts/metadata.json
python3.11 src/sign_artifact.py artifacts
python3.11 policies/test_policy.py artifacts
```

### Production Deployment
```bash
# 1. Build and push container
docker build -t ghcr.io/username/model-server:v1 .
docker push ghcr.io/username/model-server:v1

# 2. Sign container
COSIGN_EXPERIMENTAL=1 cosign sign ghcr.io/username/model-server:v1

# 3. Deploy to Kubernetes
kubectl apply -f k8s/deployment.yaml

# 4. Verify deployment
kubectl get pods -n ml-staging
kubectl logs -f deployment/model-server -n ml-staging
```

## Environment Variables

```bash
# Training
export BUILD_ID="unique-build-id"
export BUILDER_ID="github-actions"
export GIT_REPO="https://github.com/user/repo"
export GIT_COMMIT="sha256-hash"

# Serving
export MODEL_PATH="/app/artifacts/model.pkl"
export VERIFY_SIGNATURE="true"
export VERIFY_ATTESTATION="true"

# Cosign
export COSIGN_EXPERIMENTAL=1              # Enable keyless
export COSIGN_PASSWORD="key-password"     # For key-based signing
```

## Documentation Quick Links

- **Start here**: [START_HERE.md](START_HERE.md)
- **Overview**: [README.md](README.md)
- **Quick start**: [QUICKSTART.md](QUICKSTART.md)
- **Architecture**: [ARCHITECTURE.md](ARCHITECTURE.md)
- **Best practices**: [BEST_PRACTICES_REVIEW.md](BEST_PRACTICES_REVIEW.md)
- **FAQ**: [docs/FAQ.md](docs/FAQ.md)
- **Blog post**: [docs/BLOG_POST.md](docs/BLOG_POST.md)

## Keyboard Shortcuts (if using Make)

```bash
make <tab>      # Show all available commands
make help       # Show help
make all        # Full pipeline
```

---

**Pro Tip**: Bookmark this file. You'll reference it often!
