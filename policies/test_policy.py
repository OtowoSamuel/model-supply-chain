#!/usr/bin/env python3
"""
Test OPA policies against model artifacts
"""

import json
import subprocess
import sys
from typing import Dict, Any


def load_artifact_data(artifacts_dir: str = "artifacts") -> Dict[str, Any]:
    """Load all artifact data for policy evaluation"""
    
    # Load metadata
    with open(f"{artifacts_dir}/metadata.json", 'r') as f:
        metadata = json.load(f)
    
    # Load SBOMs
    with open(f"{artifacts_dir}/sbom/code-sbom.json", 'r') as f:
        code_sbom = json.load(f)
    
    with open(f"{artifacts_dir}/sbom/model-sbom.json", 'r') as f:
        model_sbom = json.load(f)
    
    # Load provenance
    with open(f"{artifacts_dir}/attestations/provenance.json", 'r') as f:
        provenance = json.load(f)
    
    # Check for signatures (Cosign v3+ uses .bundle files)
    signatures = []
    model_bundle_path = f"{artifacts_dir}/model.pkl.bundle"
    model_sig_path = f"{artifacts_dir}/model.pkl.sig"  # Fallback for older format
    import os
    if os.path.exists(model_bundle_path):
        signatures.append({
            "keyId": "cosign-key",
            "signature": "signed",
            "format": "bundle"
        })
    elif os.path.exists(model_sig_path):
        with open(model_sig_path, 'rb') as f:
            signatures.append({
                "keyId": "cosign-key",
                "signature": f.read().hex()[:64]  # Truncated for demo
            })
    
    # Construct policy input
    policy_input = {
        "metadata": metadata,
        "sbom": {
            "code": code_sbom,
            "model": model_sbom
        },
        "attestations": [provenance],
        "signatures": signatures
    }
    
    return policy_input


def evaluate_policy(policy_path: str, input_data: Dict[str, Any]) -> bool:
    """Evaluate OPA policy"""
    
    print("🔍 Evaluating OPA policy...")
    print(f"   Policy: {policy_path}")
    
    # Write input to temp file
    with open("/tmp/opa_input.json", 'w') as f:
        json.dump(input_data, f, indent=2)
    
    try:
        # Run OPA eval
        result = subprocess.run([
            "opa", "eval",
            "--data", policy_path,
            "--input", "/tmp/opa_input.json",
            "--format", "pretty",
            "data.model.deployment.allow"
        ], capture_output=True, text=True, check=True)
        
        output = result.stdout.strip()
        allowed = "true" in output.lower()
        
        print(f"\n{'✅' if allowed else '❌'} Policy evaluation: {'ALLOWED' if allowed else 'DENIED'}")
        
        # Check for violations
        violations_result = subprocess.run([
            "opa", "eval",
            "--data", policy_path,
            "--input", "/tmp/opa_input.json",
            "--format", "pretty",
            "data.model.deployment.violations"
        ], capture_output=True, text=True)
        
        if violations_result.returncode == 0:
            violations_output = violations_result.stdout.strip()
            if violations_output and "[]" not in violations_output:
                print("\n⚠️  Policy Violations:")
                print(violations_output)
        
        return allowed
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Policy evaluation failed: {e.stderr}")
        return False
    except FileNotFoundError:
        print("❌ OPA not found. Install from: https://www.openpolicyagent.org/docs/latest/#1-download-opa")
        return False


if __name__ == "__main__":
    artifacts_dir = sys.argv[1] if len(sys.argv) > 1 else "artifacts"
    policy_path = "policies/model_deployment.rego"
    
    print("🔐 Model Supply Chain Policy Evaluation\n")
    
    # Load artifact data
    input_data = load_artifact_data(artifacts_dir)
    
    # Evaluate policy
    allowed = evaluate_policy(policy_path, input_data)
    
    sys.exit(0 if allowed else 1)
