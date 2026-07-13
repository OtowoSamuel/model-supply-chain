#!/usr/bin/env python3
"""
SBOM Generation for Model Supply Chain
Generates Software Bill of Materials for both code dependencies and model metadata
"""

import os
import json
import subprocess
from datetime import datetime
from typing import Dict, List, Any
import hashlib


def generate_code_sbom(output_path: str = "artifacts/sbom/code-sbom.json"):
    """
    Generate SBOM for Python dependencies using CycloneDX format
    """
    print("📦 Generating code dependencies SBOM...")
    
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    # Use cyclonedx-py to generate SBOM from requirements
    try:
        subprocess.run([
            "cyclonedx-py",
            "requirements",
            "requirements.txt",
            "--output-format", "json",
            "--output-file", output_path
        ], check=True)
        print(f"✅ Code SBOM generated: {output_path}")
        return output_path
    except subprocess.CalledProcessError as e:
        print(f"⚠️  Failed to generate SBOM with cyclonedx-py: {e}")
        print("   Falling back to manual generation...")
        return generate_manual_sbom(output_path)


def generate_manual_sbom(output_path: str) -> str:
    """
    Fallback: Generate a basic SBOM manually if cyclonedx-py is not available
    """
    components = []
    
    # Parse requirements.txt
    if os.path.exists("requirements.txt"):
        with open("requirements.txt", "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    parts = line.replace("==", " ").split()
                    if len(parts) >= 2:
                        name, version = parts[0], parts[1]
                        components.append({
                            "type": "library",
                            "name": name,
                            "version": version,
                            "purl": f"pkg:pypi/{name}@{version}"
                        })
    
    sbom = {
        "bomFormat": "CycloneDX",
        "specVersion": "1.4",
        "serialNumber": f"urn:uuid:{generate_uuid()}",
        "version": 1,
        "metadata": {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "tools": [{
                "name": "manual-sbom-generator",
                "version": "1.0.0"
            }],
            "component": {
                "type": "application",
                "name": "ml-model-pipeline",
                "version": "1.0.0"
            }
        },
        "components": components
    }
    
    with open(output_path, 'w') as f:
        json.dump(sbom, f, indent=2)
    
    print(f"✅ Manual SBOM generated: {output_path}")
    return output_path


def generate_uuid() -> str:
    """Generate a UUID for SBOM serial number"""
    import uuid
    return str(uuid.uuid4())


def generate_model_sbom(
    model_path: str,
    metadata: Dict[str, Any],
    output_path: str = "artifacts/sbom/model-sbom.json"
):
    """
    Generate SBOM for ML model artifact including training data info and model metadata
    """
    print("🤖 Generating model artifact SBOM...")
    
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    # Calculate model hash
    model_hash = calculate_file_hash(model_path)
    
    # Create model-specific SBOM
    model_sbom = {
        "bomFormat": "CycloneDX",
        "specVersion": "1.4",
        "serialNumber": f"urn:uuid:{generate_uuid()}",
        "version": 1,
        "metadata": {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "tools": [{
                "name": "ml-sbom-generator",
                "version": "1.0.0"
            }],
            "component": {
                "type": "machine-learning-model",
                "name": metadata.get("artifact", {}).get("name", "model"),
                "version": metadata.get("version", "1.0.0"),
                "description": f"{metadata.get('model_type')} trained with {metadata.get('framework')}",
                "hashes": [{
                    "alg": "SHA-256",
                    "content": model_hash
                }],
                "properties": [
                    {"name": "model:type", "value": metadata.get("model_type", "unknown")},
                    {"name": "model:framework", "value": metadata.get("framework", "unknown")},
                    {"name": "model:accuracy", "value": str(metadata.get("accuracy", "unknown"))},
                    {"name": "model:trained_at", "value": metadata.get("trained_at", "unknown")}
                ]
            }
        },
        "components": [
            {
                "type": "data",
                "name": metadata.get("parameters", {}).get("dataset", "training-data"),
                "version": "1.0",
                "description": "Training dataset used for model training",
                "properties": [
                    {"name": "data:test_size", "value": str(metadata.get("parameters", {}).get("test_size", "unknown"))}
                ]
            }
        ],
        "dependencies": [
            {
                "ref": f"pkg:ml/{metadata.get('artifact', {}).get('name', 'model')}",
                "dependsOn": [
                    f"pkg:data/{metadata.get('parameters', {}).get('dataset', 'training-data')}"
                ]
            }
        ]
    }
    
    with open(output_path, 'w') as f:
        json.dump(model_sbom, f, indent=2)
    
    print(f"✅ Model SBOM generated: {output_path}")
    return output_path


def calculate_file_hash(filepath: str) -> str:
    """Calculate SHA256 hash of a file"""
    sha256_hash = hashlib.sha256()
    with open(filepath, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()


def generate_all_sboms(model_path: str, metadata: Dict[str, Any]):
    """Generate all SBOMs for complete supply chain visibility"""
    print("\n🔍 Generating comprehensive SBOMs...")
    
    sboms = {
        "code": generate_code_sbom(),
        "model": generate_model_sbom(model_path, metadata)
    }
    
    print("\n✨ All SBOMs generated successfully!")
    return sboms


if __name__ == "__main__":
    # Example usage
    import sys
    
    if len(sys.argv) > 1:
        metadata_path = sys.argv[1]
        with open(metadata_path, 'r') as f:
            metadata = json.load(f)
        
        model_path = os.path.join(os.path.dirname(metadata_path), "model.pkl")
        generate_all_sboms(model_path, metadata)
    else:
        print("Usage: python generate_sbom.py <metadata.json>")
        print("Or import and use generate_all_sboms() function")
