# Security Policy

## Threat Model

This project addresses supply chain security threats in ML pipelines:

### In Scope

1. **Model Tampering**: Unauthorized modification of trained models
2. **Supply Chain Attacks**: Compromised dependencies in training pipeline
3. **Provenance Forgery**: False claims about model origin
4. **Deployment of Unsigned Models**: Serving unverified artifacts
5. **Insider Threats**: Malicious model submission by authorized users

### Out of Scope

1. **Adversarial Examples**: Evasion attacks at inference time (see [Adversarial Robustness Toolbox](https://github.com/Trusted-AI/adversarial-robustness-toolbox))
2. **Model Extraction**: Stealing model parameters via API queries
3. **Training Data Privacy**: Membership inference attacks (see [TensorFlow Privacy](https://github.com/tensorflow/privacy))
4. **Model Bias**: Fairness and bias in predictions (see [AI Fairness 360](https://github.com/Trusted-AI/AIF360))

## Security Features

### Implemented

- ✅ **Cryptographic Signing**: All artifacts signed with Cosign
- ✅ **Transparency Logging**: Signatures recorded in Rekor (keyless mode)
- ✅ **SLSA Provenance**: Build metadata tracked with attestations
- ✅ **SBOM Generation**: Dependency visibility for vulnerability scanning
- ✅ **Policy Enforcement**: OPA and Kyverno gates block unsigned models
- ✅ **Runtime Verification**: Model server validates signatures before loading

### Limitations

- **Training Data Provenance**: Dataset versioning not fully implemented (add DVC/Git LFS)
- **Hermetic Builds**: Not fully isolated (SLSA L3, not L4)
- **Model Watermarking**: No embedded tamper detection in weights
- **Continuous Verification**: Signatures checked at load time only (add periodic re-verification)

## Best Practices

### Development

1. **Never commit private keys**: Add `*.key`, `*.pem` to `.gitignore`
2. **Use keyless signing in CI/CD**: Leverage OIDC tokens (no key management)
3. **Rotate keys regularly**: If using key-based signing, rotate every 90 days
4. **Pin dependencies**: Use exact versions in `requirements.txt`

### Production

1. **Enable signature verification**: Always run with `VERIFY_SIGNATURE=true`
2. **Deploy Kyverno policies**: Block unsigned images at admission
3. **Monitor Rekor logs**: Audit transparency logs for unexpected signatures
4. **Scan SBOMs**: Integrate Grype/Trivy in CI to catch CVEs
5. **Require SLSA provenance**: Reject models without attestations

### Key Management

#### Keyless (Recommended for CI/CD)

```bash
# GitHub Actions
- name: Sign with Cosign
  env:
    COSIGN_EXPERIMENTAL: 1  # Enable keyless
  run: cosign sign-blob model.pkl --yes
```

#### Key-Based (Air-Gapped Environments)

```bash
# Generate keys
cosign generate-key-pair

# Store private key securely
export COSIGN_PASSWORD=...  # Strong password
# Store in vault: AWS Secrets Manager, HashiCorp Vault, etc.

# Sign
cosign sign-blob model.pkl --key cosign.key

# Distribute public key for verification
kubectl create secret generic cosign-public-key \
  --from-file=cosign.pub=keys/cosign.pub \
  -n ml-production
```

## Vulnerability Reporting

### Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |
| < 1.0   | :x:                |

### Reporting a Vulnerability

**Do not open public issues for security vulnerabilities.**

Email security reports to: [security@yourdomain.com]

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

Expected response time: 48 hours for acknowledgment, 7 days for triage.

## Security Audits

### Last Audit

- **Date**: Not yet audited
- **Scope**: N/A
- **Findings**: N/A

### Recommended Audits

For production use, audit:
1. Cosign signature verification logic
2. OPA policy completeness
3. Kubernetes RBAC and Kyverno policies
4. Container image hardening
5. Secret management practices

## Compliance

### Standards Alignment

- **SLSA**: Targets Level 3 (signed provenance, trusted builder)
- **NIST AI RMF**: Addresses governance, security, and transparency
- **MITRE ATLAS**: Mitigates AML.T0000 series (supply chain attacks)
- **OWASP ML Top 10**: Covers ML03, ML05

### Regulatory Considerations

This architecture supports:
- **EU AI Act**: Transparency and documentation requirements
- **GDPR**: Provenance aids in data lineage tracking
- **SOC 2**: Demonstrates security controls for ML systems
- **ISO 27001**: Supply chain risk management

## References

- [Sigstore Security Model](https://docs.sigstore.dev/security/)
- [SLSA Requirements](https://slsa.dev/spec/v1.0/requirements)
- [in-toto Security](https://github.com/in-toto/docs/blob/master/in-toto-spec.md#5-security)
- [MITRE ATLAS](https://atlas.mitre.org/)
- [OWASP ML Security](https://owasp.org/www-project-machine-learning-security-top-10/)
