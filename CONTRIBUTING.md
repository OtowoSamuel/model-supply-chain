# Contributing to Model Supply Chain Security

Thank you for your interest in contributing! This project aims to fill a critical gap in ML security, and we welcome contributions from the community.

## How to Contribute

### 1. Areas Where We Need Help

#### High Priority
- **Framework Support**: Add TensorFlow, PyTorch, JAX examples
- **MLOps Integration**: Connectors for MLflow, Weights & Biases, Kubeflow
- **Cloud Platform Examples**: AWS SageMaker, Azure ML, GCP Vertex AI
- **Testing**: Unit tests, integration tests, E2E tests
- **Documentation**: Tutorials, case studies, troubleshooting guides

#### Medium Priority
- **SLSA Level 4**: Implement hermetic builds
- **Training Data Provenance**: DVC integration, dataset versioning
- **Model Drift Detection**: Continuous verification
- **Fairness Metrics**: Bias detection in policies
- **Differential Privacy**: Privacy attestations

#### Community Requests
- Additional policy examples (PII detection, bias thresholds)
- Windows support
- Air-gapped environment setup
- Multi-tenant scenarios

### 2. Development Setup

```bash
# Clone repo
git clone https://github.com/yourusername/model-supply-chain.git
cd model-supply-chain

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt  # If you create this

# Install tools
brew install cosign opa  # macOS
```

### 3. Making Changes

#### Code Style
- Follow PEP 8 for Python
- Use type hints where possible
- Add docstrings to functions
- Keep functions focused and testable

#### Commit Messages

Follow conventional commits:
```
feat: add TensorFlow SBOM generator
fix: correct signature verification logic
docs: update QUICKSTART with PyTorch example
test: add unit tests for provenance tracker
```

#### Branch Naming
- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation only
- `test/description` - Test additions

### 4. Pull Request Process

1. **Fork** the repository
2. **Create** a feature branch
3. **Make** your changes
4. **Test** locally (run demo, verify signatures)
5. **Commit** with clear messages
6. **Push** to your fork
7. **Open** a PR with description

#### PR Checklist
- [ ] Code follows project style
- [ ] Documentation updated (if needed)
- [ ] Examples work end-to-end
- [ ] No secrets committed
- [ ] Tests pass (if applicable)

### 5. Reporting Issues

#### Bug Reports
Include:
- Operating system and version
- Python version
- Cosign version
- Steps to reproduce
- Expected vs actual behavior
- Error messages/logs

#### Feature Requests

Include:
- Use case or problem statement
- Proposed solution (if any)
- Examples or pseudocode
- Why this benefits the project

### 6. Code of Conduct

We follow the [Contributor Covenant](https://www.contributor-covenant.org/):

- Be respectful and inclusive
- Welcome newcomers
- Focus on what's best for the community
- Show empathy towards others

### 7. Security Issues

**Do not open public issues for security vulnerabilities.**

Email: security@yourdomain.com

Include:
- Vulnerability description
- Impact assessment
- Steps to reproduce
- Suggested fix (optional)

## Project Structure

```
model-supply-chain/
├── src/              # Core implementation
├── policies/         # OPA policies
├── k8s/              # Kubernetes manifests
├── examples/         # Usage examples
├── scripts/          # Automation scripts
├── docs/             # Documentation
└── tests/            # Tests (to be added)
```

## Testing Guidelines

### Manual Testing

Run the E2E demo:
```bash
./scripts/e2e-demo.sh
```

### Integration Testing


Test specific components:
```bash
# Train model
make train

# Verify signatures
python examples/verify_model.py artifacts keys/cosign.pub

# Test OPA policy
make policy

# Test API
./examples/test_api.sh
```

## Documentation Standards

- Use clear, concise language
- Include code examples
- Add diagrams where helpful
- Link to official docs for tools
- Test all commands before submitting

## Questions?

- Open a discussion on GitHub
- Join our community chat (if available)
- Review existing issues and PRs

Thank you for contributing! 🙏
