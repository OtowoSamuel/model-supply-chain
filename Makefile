.PHONY: help install train sign verify serve policy docker clean

help:
	@echo "Model Supply Chain Security - Make Commands"
	@echo ""
	@echo "Development:"
	@echo "  make install     - Install Python dependencies"
	@echo "  make train       - Train model with provenance"
	@echo "  make sign        - Sign artifacts with cosign"
	@echo "  make verify      - Verify signatures"
	@echo "  make policy      - Test OPA policy"
	@echo "  make serve       - Start model server"
	@echo ""
	@echo "Docker:"
	@echo "  make docker      - Build Docker image"
	@echo "  make docker-run  - Run Docker container"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean       - Clean generated artifacts"
	@echo "  make keys        - Generate cosign keys"

install:
	@echo "📦 Installing dependencies..."
	pip install --upgrade pip
	pip install -r requirements.txt

train:
	@echo "🚀 Training model with provenance tracking..."
	python src/train_model.py
	python src/generate_sbom.py artifacts/metadata.json

sign: keys
	@echo "✍️  Signing artifacts..."
	python src/sign_artifact.py artifacts

keys:
	@echo "🔑 Generating cosign keys..."
	@mkdir -p keys
	@if [ ! -f keys/cosign.key ]; then \
		cosign generate-key-pair --output-key-prefix keys/cosign; \
	else \
		echo "Keys already exist"; \
	fi

verify:
	@echo "🔍 Verifying signatures..."
	cosign verify-blob artifacts/model.pkl \
		--key keys/cosign.pub \
		--signature artifacts/model.pkl.sig

policy:
	@echo "🚦 Evaluating OPA policy..."
	python policies/test_policy.py artifacts

serve:
	@echo "🚀 Starting model server..."
	python src/model_server.py

docker:
	@echo "🐳 Building Docker image..."
	docker build -t model-server:latest .

docker-run:
	@echo "🚀 Running Docker container..."
	docker run -p 8080:8080 model-server:latest

test-prediction:
	@echo "🧪 Testing prediction endpoint..."
	curl -X POST http://localhost:8080/predict \
		-H "Content-Type: application/json" \
		-d '{"features": [5.1, 3.5, 1.4, 0.2]}'

clean:
	@echo "🧹 Cleaning artifacts..."
	rm -rf artifacts/
	rm -rf keys/
	rm -rf __pycache__/
	rm -rf src/__pycache__/
	rm -f /tmp/opa_input.json

all: install train sign policy
	@echo "✅ Full pipeline complete!"
