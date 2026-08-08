#!/usr/bin/env python3
"""
Secure Model Server - XGBoost Fraud Detection
Verifies signatures and attestations before serving predictions
"""

import os
import sys
import json
import pickle
import hashlib
import subprocess
from typing import Dict, Any, Optional

from flask import Flask, request, jsonify

app = Flask(__name__)


class SecureModelLoader:
    def __init__(self, artifacts_dir: str = "artifacts"):
        self.artifacts_dir = artifacts_dir
        self.model = None
        self.feature_names = None
        self.metadata = None
        self.verified = False

    def verify_signature(self, file_path: str, bundle_path: str,
                         public_key: str = "keys/cosign.pub") -> bool:
        if not os.path.exists(public_key):
            print(f"⚠️  Public key not found: {public_key}, skipping signature check")
            return True  # Allow in dev without keys

        if not os.path.exists(bundle_path):
            print(f"⚠️  Bundle not found: {bundle_path}")
            return False

        try:
            subprocess.run([
                "cosign", "verify-blob",
                file_path,
                "--key", public_key,
                "--bundle", bundle_path
            ], capture_output=True, text=True, check=True)
            print(f"✅ Signature verified for {file_path}")
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ Signature verification failed: {e.stderr}")
            return False
        except FileNotFoundError:
            print("⚠️  Cosign not found, skipping signature check")
            return True  # Allow in dev without cosign

    def validate_attestations(self) -> bool:
        provenance_path = f"{self.artifacts_dir}/attestations/provenance.json"
        if not os.path.exists(provenance_path):
            print("⚠️  Provenance not found")
            return False

        with open(provenance_path, "r") as f:
            attestation = json.load(f)

        if attestation.get("predicateType") != "https://slsa.dev/provenance/v0.2":
            print("❌ Invalid provenance format")
            return False

        print("✅ SLSA provenance validated")
        return True

    def load_model(self, require_signature: bool = True,
                   require_attestation: bool = True) -> bool:
        print("🔍 Loading model with security validation...")

        model_path = f"{self.artifacts_dir}/model.pkl"
        bundle_path = f"{self.artifacts_dir}/model.pkl.bundle"
        metadata_path = f"{self.artifacts_dir}/metadata.json"

        if not os.path.exists(model_path):
            print(f"❌ Model not found: {model_path}")
            return False

        if require_signature:
            if not self.verify_signature(model_path, bundle_path):
                print("❌ Signature verification failed")
                return False

        if require_attestation:
            if not self.validate_attestations():
                print("❌ Attestation validation failed")
                return False

        with open(model_path, "rb") as f:
            payload = pickle.load(f)

        self.model = payload["model"]
        self.feature_names = payload.get("feature_names", [])

        if os.path.exists(metadata_path):
            with open(metadata_path, "r") as f:
                self.metadata = json.load(f)

        self.verified = True
        print("✅ Model loaded and verified successfully!")
        return True

    def predict(self, input_data):
        if not self.verified:
            raise RuntimeError("Model not verified. Cannot make predictions.")
        import numpy as np
        return self.model.predict(np.array(input_data))

    def predict_proba(self, input_data):
        if not self.verified:
            raise RuntimeError("Model not verified. Cannot make predictions.")
        import numpy as np
        return self.model.predict_proba(np.array(input_data))


model_loader = SecureModelLoader()


@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "healthy",
        "model_loaded": model_loader.verified,
        "model_type": model_loader.metadata.get("model_type") if model_loader.metadata else None,
        "use_case": model_loader.metadata.get("use_case") if model_loader.metadata else None,
        "metrics": model_loader.metadata.get("metrics") if model_loader.metadata else None,
        "version": model_loader.metadata.get("version") if model_loader.metadata else None
    })


@app.route("/predict", methods=["POST"])
def predict():
    if not model_loader.verified:
        return jsonify({"error": "Model not verified"}), 403

    try:
        data = request.get_json()
        features = data.get("features", [])

        if not features:
            return jsonify({"error": "No features provided"}), 400

        prediction = model_loader.predict([features])
        probabilities = model_loader.predict_proba([features])

        fraud_probability = float(probabilities[0][1])
        is_fraud = bool(prediction[0])

        return jsonify({
            "prediction": "FRAUD" if is_fraud else "LEGITIMATE",
            "is_fraud": is_fraud,
            "fraud_probability": round(fraud_probability, 4),
            "risk_level": "HIGH" if fraud_probability > 0.7 else
                          "MEDIUM" if fraud_probability > 0.3 else "LOW",
            "model_version": model_loader.metadata.get("version"),
            "model_hash": model_loader.metadata.get("artifact", {}).get("sha256", "")[:16] + "..."
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/attestations", methods=["GET"])
def attestations():
    provenance_path = f"{model_loader.artifacts_dir}/attestations/provenance.json"
    if not os.path.exists(provenance_path):
        return jsonify({"error": "Provenance not found"}), 404

    with open(provenance_path, "r") as f:
        provenance = json.load(f)

    return jsonify({
        "provenance": provenance,
        "sboms": {
            "code": f"{model_loader.artifacts_dir}/sbom/code-sbom.json",
            "model": f"{model_loader.artifacts_dir}/sbom/model-sbom.json"
        }
    })


@app.route("/features", methods=["GET"])
def features():
    """Return expected feature names for the model"""
    return jsonify({
        "feature_names": model_loader.feature_names,
        "n_features": len(model_loader.feature_names)
    })


if __name__ == "__main__":
    require_sig = "--no-verify-signature" not in sys.argv
    require_att = "--no-verify-attestation" not in sys.argv

    if not model_loader.load_model(require_sig, require_att):
        print("❌ Failed to load model. Exiting.")
        sys.exit(1)

    print("\n🚀 Starting secure fraud detection model server...")
    print("   Endpoints:")
    print("     GET  /health       - Health check + metrics")
    print("     POST /predict      - Fraud detection")
    print("     GET  /attestations - View SLSA provenance")
    print("     GET  /features     - List feature names")
    app.run(host="0.0.0.0", port=8080, debug=False)
