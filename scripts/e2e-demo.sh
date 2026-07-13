#!/bin/bash
set -e

echo "🚀 Model Supply Chain Security - End-to-End Demo"
echo "=================================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

command -v python3 >/dev/null 2>&1 || { echo "❌ Python3 required but not installed."; exit 1; }
command -v cosign >/dev/null 2>&1 || { echo "❌ Cosign required. Install from: https://docs.sigstore.dev/cosign/installation/"; exit 1; }
command -v opa >/dev/null 2>&1 || { echo "⚠️  OPA recommended. Install from: https://www.openpolicyagent.org/"; }

echo -e "${GREEN}✅ Prerequisites OK${NC}"
echo ""

# Step 1: Install dependencies
echo -e "${BLUE}Step 1: Installing Python dependencies...${NC}"
pip install -q -r requirements.txt
echo -e "${GREEN}✅ Dependencies installed${NC}"
echo ""

# Step 2: Train model
echo -e "${BLUE}Step 2: Training model with provenance tracking...${NC}"
python src/train_model.py
echo -e "${GREEN}✅ Model trained${NC}"
echo ""

# Step 3: Generate SBOMs
echo -e "${BLUE}Step 3: Generating SBOMs...${NC}"
python src/generate_sbom.py artifacts/metadata.json
echo -e "${GREEN}✅ SBOMs generated${NC}"
echo ""

# Step 4: Sign artifacts
echo -e "${BLUE}Step 4: Signing artifacts with Cosign...${NC}"
if [ ! -f "keys/cosign.key" ]; then
    echo "Generating cosign keypair..."
    mkdir -p keys
    COSIGN_PASSWORD="" cosign generate-key-pair --output-key-prefix keys/cosign
fi
python src/sign_artifact.py artifacts
echo -e "${GREEN}✅ Artifacts signed${NC}"
echo ""

# Step 5: Verify signatures
echo -e "${BLUE}Step 5: Verifying signatures...${NC}"
python examples/verify_model.py artifacts keys/cosign.pub
echo -e "${GREEN}✅ Signatures verified${NC}"
echo ""

# Step 6: Evaluate OPA policy
if command -v opa >/dev/null 2>&1; then
    echo -e "${BLUE}Step 6: Evaluating OPA deployment policy...${NC}"
    python policies/test_policy.py artifacts
    echo -e "${GREEN}✅ Policy checks passed${NC}"
    echo ""
else
    echo -e "${YELLOW}⏭️  Skipping OPA policy (not installed)${NC}"
    echo ""
fi

# Step 7: Start model server (optional)
echo -e "${BLUE}Step 7: Model server ready${NC}"
echo ""
echo "To start the model server:"
echo "  python src/model_server.py"
echo ""
echo "Then test with:"
echo "  curl -X POST http://localhost:8080/predict \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"features\": [5.1, 3.5, 1.4, 0.2]}'"
echo ""

# Summary
echo "=================================================="
echo -e "${GREEN}✨ Demo complete! Your model supply chain is secure.${NC}"
echo ""
echo "Generated artifacts:"
echo "  📦 artifacts/model.pkl (signed)"
echo "  📜 artifacts/sbom/ (code + model SBOMs)"
echo "  🔏 artifacts/attestations/provenance.json"
echo "  🔑 keys/cosign.key + cosign.pub"
echo ""
echo "Next steps:"
echo "  1. Review the SBOMs: cat artifacts/sbom/*.json"
echo "  2. Inspect provenance: cat artifacts/attestations/provenance.json"
echo "  3. Start serving: python src/model_server.py"
echo "  4. Build container: docker build -t model-server ."
echo ""
