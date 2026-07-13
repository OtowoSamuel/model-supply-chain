#!/usr/bin/env python3
"""
Model Training Pipeline with Provenance Tracking
Trains a simple ML model and generates metadata for supply chain security
"""

import os
import json
import hashlib
import pickle
from datetime import datetime
from typing import Dict, Any

import numpy as np
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report


class ProvenanceTracker:
    """Track build provenance information for SLSA compliance"""
    
    def __init__(self, build_id: str = None):
        self.build_id = build_id or os.getenv("BUILD_ID", f"local-{datetime.utcnow().isoformat()}")
        self.provenance = {
            "buildType": "https://github.com/ml-supply-chain/v1",
            "builder": {
                "id": os.getenv("BUILDER_ID", "local-builder")
            },
            "invocation": {
                "configSource": {
                    "uri": os.getenv("GIT_REPO", "unknown"),
                    "digest": {
                        "sha256": os.getenv("GIT_COMMIT", "unknown")
                    }
                },
                "parameters": {},
                "environment": {
                    "python_version": os.sys.version,
                    "platform": os.sys.platform
                }
            },
            "metadata": {
                "buildInvocationId": self.build_id,
                "buildStartedOn": datetime.utcnow().isoformat() + "Z",
                "buildFinishedOn": None,
                "completeness": {
                    "parameters": True,
                    "environment": True,
                    "materials": True
                },
                "reproducible": True
            },
            "materials": []
        }
    
    def add_material(self, uri: str, digest: str):
        """Add a material (dependency) to provenance"""
        self.provenance["materials"].append({
            "uri": uri,
            "digest": {"sha256": digest}
        })
    
    def set_parameters(self, params: Dict[str, Any]):
        """Set build parameters"""
        self.provenance["invocation"]["parameters"] = params
    
    def finalize(self, subject_digest: str):
        """Finalize provenance with output artifact"""
        self.provenance["metadata"]["buildFinishedOn"] = datetime.utcnow().isoformat() + "Z"
        self.provenance["subject"] = [{
            "name": "model.pkl",
            "digest": {"sha256": subject_digest}
        }]
        return self.provenance


def calculate_file_hash(filepath: str) -> str:
    """Calculate SHA256 hash of a file"""
    sha256_hash = hashlib.sha256()
    with open(filepath, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()


def train_model(output_dir: str = "artifacts") -> Dict[str, Any]:
    """
    Train a model with full provenance tracking
    
    Returns:
        Dict containing model metadata and provenance information
    """
    print("🚀 Starting model training pipeline...")
    
    # Initialize provenance tracker
    provenance_tracker = ProvenanceTracker()
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(f"{output_dir}/attestations", exist_ok=True)
    
    # Load and prepare data
    print("📊 Loading training data...")
    iris = load_iris()
    X_train, X_test, y_train, y_test = train_test_split(
        iris.data, iris.target, test_size=0.2, random_state=42
    )
    
    # Model hyperparameters
    params = {
        "n_estimators": 100,
        "max_depth": 5,
        "random_state": 42,
        "dataset": "iris",
        "test_size": 0.2
    }
    provenance_tracker.set_parameters(params)
    
    # Train model
    print("🧠 Training Random Forest model...")
    model = RandomForestClassifier(
        n_estimators=params["n_estimators"],
        max_depth=params["max_depth"],
        random_state=params["random_state"]
    )
    model.fit(X_train, y_train)
    
    # Evaluate
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    print(f"✅ Model accuracy: {accuracy:.4f}")
    
    # Save model
    model_path = f"{output_dir}/model.pkl"
    print(f"💾 Saving model to {model_path}...")
    with open(model_path, 'wb') as f:
        pickle.dump(model, f)
    
    # Calculate model hash
    model_hash = calculate_file_hash(model_path)
    print(f"🔐 Model SHA256: {model_hash}")
    
    # Track requirements.txt as material
    if os.path.exists("requirements.txt"):
        req_hash = calculate_file_hash("requirements.txt")
        provenance_tracker.add_material("pkg:requirements.txt", req_hash)
    
    # Generate metadata
    metadata = {
        "model_type": "RandomForestClassifier",
        "framework": "scikit-learn",
        "version": "1.0.0",
        "trained_at": datetime.utcnow().isoformat() + "Z",
        "accuracy": float(accuracy),
        "parameters": params,
        "artifact": {
            "name": "model.pkl",
            "size_bytes": os.path.getsize(model_path),
            "sha256": model_hash
        }
    }
    
    metadata_path = f"{output_dir}/metadata.json"
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f, indent=2)
    print(f"📝 Metadata saved to {metadata_path}")
    
    # Generate SLSA provenance
    provenance = provenance_tracker.finalize(model_hash)
    provenance_path = f"{output_dir}/attestations/provenance.json"
    
    # Wrap in in-toto attestation format
    attestation = {
        "_type": "https://in-toto.io/Statement/v0.1",
        "predicateType": "https://slsa.dev/provenance/v0.2",
        "subject": provenance["subject"],
        "predicate": {k: v for k, v in provenance.items() if k != "subject"}
    }
    
    with open(provenance_path, 'w') as f:
        json.dump(attestation, f, indent=2)
    print(f"📜 SLSA provenance saved to {provenance_path}")
    
    print("✨ Training pipeline complete!")
    
    return {
        "model_path": model_path,
        "model_hash": model_hash,
        "metadata": metadata,
        "provenance": attestation,
        "accuracy": accuracy
    }


if __name__ == "__main__":
    result = train_model()
    print(f"\n🎯 Model training complete!")
    print(f"   Hash: {result['model_hash']}")
    print(f"   Accuracy: {result['accuracy']:.4f}")
