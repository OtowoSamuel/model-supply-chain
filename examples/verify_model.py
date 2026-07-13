#!/usr/bin/env python3
"""
Verify model artifacts before deployment
Standalone verification script for CI/CD or manual checks
"""

import os
import sys
import json
import subprocess
from typing import Dict, Any, Tuple


def verify_signature(file_path: str, signature_path: str, public_key: str) -> Tuple[bool, str]:
    """Verify cosign signature"""
    if not os.path.exists(file_path):
        return False, f"File not found: {file_path}"
    
    if not os.path.exists(signature_path):
        return False, f"Signature not found: {signature_path}"
    
    if not os.path.exists(public_key):
        return False, f"Public key not found: {public_key}"
    
    try:
        result = subprocess.run([
            "cosign", "verify-blob",
            file_path,
            "--key", public_key,
            "--signature", signature_path
        ], capture_output=True, text=True, check=True)
        
        return True, "Signature valid"
    except subprocess.CalledProcessError as e:
        return False, f"Signature verification failed: {e.stderr}"
    except FileNotFoundError:
        return False, "cosign not found - install from https://docs.sigstore.dev/cosign/installation/"


def verify_sbom(sbom_path: str) -> Tuple[bool, str]:
    """Verify SBOM structure"""
    if not os.path.exists(sbom_path):
        return False, f"SBOM not found: {sbom_path}"
    
    try:
        with open(sbom_path, 'r') as f:
            sbom = json.load(f)
        
        # Check CycloneDX format
        if sbom.get("bomFormat") != "CycloneDX":
            return False, "Invalid SBOM format - must be CycloneDX"
        
        # Check required fields
        required = ["specVersion", "serialNumber", "metadata"]
        missing = [field for field in required if field not in sbom]
        if missing:
            return False, f"Missing SBOM fields: {', '.join(missing)}"
        
        component_count = len(sbom.get("components", []))
        return True, f"Valid SBOM with {component_count} components"
    
    except json.JSONDecodeError as e:
        return False, f"Invalid JSON: {e}"
    except Exception as e:
        return False, f"SBOM validation error: {e}"


def verify_provenance(provenance_path: str) -> Tuple[bool, str]:
    """Verify SLSA provenance structure"""
    if not os.path.exists(provenance_path):
        return False, f"Provenance not found: {provenance_path}"
    
    try:
        with open(provenance_path, 'r') as f:
            attestation = json.load(f)
        
        # Check in-toto attestation format
        if attestation.get("_type") != "https://in-toto.io/Statement/v0.1":
            return False, "Invalid attestation format"
        
        # Check SLSA provenance
        if attestation.get("predicateType") != "https://slsa.dev/provenance/v0.2":
            return False, "Invalid provenance type"
        
        # Check required fields
        predicate = attestation.get("predicate", {})
        required = ["buildType", "builder", "invocation"]
        missing = [field for field in required if field not in predicate]
        if missing:
            return False, f"Missing provenance fields: {', '.join(missing)}"
        
        builder_id = predicate.get("builder", {}).get("id", "unknown")
        return True, f"Valid SLSA provenance from builder: {builder_id}"
    
    except json.JSONDecodeError as e:
        return False, f"Invalid JSON: {e}"
    except Exception as e:
        return False, f"Provenance validation error: {e}"


def verify_model_quality(metadata_path: str, min_accuracy: float = 0.85) -> Tuple[bool, str]:
    """Verify model meets quality threshold"""
    if not os.path.exists(metadata_path):
        return False, f"Metadata not found: {metadata_path}"
    
    try:
        with open(metadata_path, 'r') as f:
            metadata = json.load(f)
        
        accuracy = metadata.get("accuracy")
        if accuracy is None:
            return False, "Accuracy not found in metadata"
        
        if accuracy < min_accuracy:
            return False, f"Accuracy {accuracy:.4f} below threshold {min_accuracy}"
        
        return True, f"Model accuracy {accuracy:.4f} meets threshold"
    
    except json.JSONDecodeError as e:
        return False, f"Invalid JSON: {e}"
    except Exception as e:
        return False, f"Metadata validation error: {e}"


def main():
    """Run all verification checks"""
    artifacts_dir = sys.argv[1] if len(sys.argv) > 1 else "artifacts"
    public_key = sys.argv[2] if len(sys.argv) > 2 else "keys/cosign.pub"
    
    print("🔍 Model Artifact Verification\n")
    print(f"Artifacts directory: {artifacts_dir}")
    print(f"Public key: {public_key}\n")
    
    checks = []
    
    # 1. Verify model signature
    print("1️⃣  Verifying model signature...")
    success, message = verify_signature(
        f"{artifacts_dir}/model.pkl",
        f"{artifacts_dir}/model.pkl.sig",
        public_key
    )
    print(f"   {'✅' if success else '❌'} {message}")
    checks.append(("Model signature", success))
    
    # 2. Verify code SBOM
    print("\n2️⃣  Verifying code SBOM...")
    success, message = verify_sbom(f"{artifacts_dir}/sbom/code-sbom.json")
    print(f"   {'✅' if success else '❌'} {message}")
    checks.append(("Code SBOM", success))
    
    # 3. Verify model SBOM
    print("\n3️⃣  Verifying model SBOM...")
    success, message = verify_sbom(f"{artifacts_dir}/sbom/model-sbom.json")
    print(f"   {'✅' if success else '❌'} {message}")
    checks.append(("Model SBOM", success))
    
    # 4. Verify SLSA provenance
    print("\n4️⃣  Verifying SLSA provenance...")
    success, message = verify_provenance(f"{artifacts_dir}/attestations/provenance.json")
    print(f"   {'✅' if success else '❌'} {message}")
    checks.append(("SLSA provenance", success))
    
    # 5. Verify model quality
    print("\n5️⃣  Verifying model quality...")
    success, message = verify_model_quality(f"{artifacts_dir}/metadata.json")
    print(f"   {'✅' if success else '❌'} {message}")
    checks.append(("Model quality", success))
    
    # Summary
    print("\n" + "="*60)
    passed = sum(1 for _, success in checks if success)
    total = len(checks)
    
    print(f"Results: {passed}/{total} checks passed\n")
    
    for check_name, success in checks:
        print(f"  {'✅' if success else '❌'} {check_name}")
    
    print("="*60)
    
    if passed == total:
        print("\n✨ All verification checks passed! Model is ready for deployment.")
        sys.exit(0)
    else:
        print("\n❌ Verification failed. Do not deploy this model.")
        sys.exit(1)


if __name__ == "__main__":
    main()
