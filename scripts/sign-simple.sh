#!/bin/bash
# Simple signing script using Cosign v3+ bundle format

set -e

echo "🔐 Simple Artifact Signing"
echo ""

# Check if cosign is installed
if ! command -v cosign &> /dev/null; then
    echo "❌ Cosign not found. Install with: brew install cosign"
    exit 1
fi

# Check if keys exist
if [ ! -f "keys/cosign.key" ]; then
    echo "🔑 Generating cosign keypair..."
    mkdir -p keys
    cosign generate-key-pair --output-key-prefix keys/cosign
    echo ""
fi

echo "✅ Using existing keys"
echo ""

# Sign model
echo "✍️  Signing model..."
if [ -f "artifacts/model.pkl" ]; then
    cosign sign-blob artifacts/model.pkl \
        --key keys/cosign.key \
        --bundle artifacts/model.pkl.bundle
    echo "✅ Model signed: artifacts/model.pkl.bundle"
else
    echo "⚠️  No model found at artifacts/model.pkl"
fi
echo ""

# Sign SBOMs
echo "✍️  Signing SBOMs..."
if [ -f "artifacts/sbom/code-sbom.json" ]; then
    cosign sign-blob artifacts/sbom/code-sbom.json \
        --key keys/cosign.key \
        --bundle artifacts/sbom/code-sbom.json.bundle
    echo "✅ Code SBOM signed"
fi

if [ -f "artifacts/sbom/model-sbom.json" ]; then
    cosign sign-blob artifacts/sbom/model-sbom.json \
        --key keys/cosign.key \
        --bundle artifacts/sbom/model-sbom.json.bundle
    echo "✅ Model SBOM signed"
fi
echo ""

# Sign provenance
echo "✍️  Signing provenance..."
if [ -f "artifacts/attestations/provenance.json" ]; then
    cosign sign-blob artifacts/attestations/provenance.json \
        --key keys/cosign.key \
        --bundle artifacts/attestations/provenance.json.bundle
    echo "✅ Provenance signed"
fi
echo ""

echo "✨ All artifacts signed successfully!"
echo ""
echo "Bundles created:"
ls -lh artifacts/*.bundle artifacts/sbom/*.bundle artifacts/attestations/*.bundle 2>/dev/null || true
