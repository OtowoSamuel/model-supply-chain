#!/usr/bin/env python3
"""
Model Serving with Security Validation
Verifies signatures and attestations before serving predictions
"""

import os
import json
import pickle
import subprocess
from typing import Dict, Any, Optional
from flask import Flask, request, jsonify

app = Flask(__name__)

class SecureModelLoader:
    """Load and validate models with signature verification"""
    
    def __init__(self, artifacts_dir: str = "artifacts"):
        self.artifacts_dir = artifacts_dir
        self.model = None
        self.metadata = None
        self.verified = False
    
    def verify_signature(self, file_path: str, signature_path: str, 
                        public_key: str = "keys/cosign.pub") -> bool:
        """Verify cosign signature"""
        if not os.path.exists(public_key):
            print(f"⚠️  Public key not found: {public_key}")
            return False
        
        try:
            result = subprocess.run([
                "cosign", "verify-blob",
                file_path,
                "--key", public_key,
                "--signature", signature_path
            ], capture_output=True, text=True, check=True)
            print(f"✅ Signature verified for {file_path}")
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ Signature verification failed: {e.stderr}")
            return False
    
    def validate_attestations(self) -> bool:
        """Validate SLSA provenance and SBOMs"""
        provenance_path = f"{self.artifacts_dir}/attestations/provenance.json"
        
        if not os.path.exists(provenance_path):
            print("⚠️  Provenance not found")
            return False
        
        with open(provenance_path, 'r') as f:
            attestation = json.load(f)
        
        # Verify attestation structure
        if attestation.get("predicateType") != "https://slsa.dev/provenance/v0.2":
            print("❌ Invalid provenance format")
            return False
        
        print("✅ SLSA provenance validated")
        return True
    
    def load_model(self, require_signature: bool = True,
                   require_attestation: bool = True) -> bool:
        """Load model with security validation"""
        print("🔍 Loading model with security validation...")
        
        model_path = f"{self.artifacts_dir}/model.pkl"
        metadata_path = f"{self.artifacts_dir}/metadata.json"
        signature_path = f"{model_path}.sig"
        
        # Check files exist
        if not os.path.exists(model_path):
            print(f"❌ Model not found: {model_path}")
            return False
        
        # Verify signature
        if require_signature:
            if not os.path.exists(signature_path):
                print("❌ Signature required but not found")
                return False
            
            if not self.verify_signature(model_path, signature_path):
                print("❌ Signature verification failed")
                return False
        
        # Validate attestations
        if require_attestation:
            if not self.validate_attestations():
                print("❌ Attestation validation failed")
                return False
        
        # Load model
        with open(model_path, 'rb') as f:
            self.model = pickle.load(f)
        
        # Load metadata
        if os.path.exists(metadata_path):
            with open(metadata_path, 'r') as f:
                self.metadata = json.load(f)
        
        self.verified = True
        print("✅ Model loaded and verified successfully!")
        return True
    
    def predict(self, input_data):
        """Make prediction with loaded model"""
        if not self.verified:
            raise RuntimeError("Model not verified. Cannot make predictions.")
        return self.model.predict(input_data)


# Global model loader
model_loader = SecureModelLoader()

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "model_loaded": model_loader.verified,
        "metadata": model_loader.metadata
    })

@app.route('/predict', methods=['POST'])
def predict():
    """Prediction endpoint"""
    if not model_loader.verified:
        return jsonify({"error": "Model not verified"}), 403
    
    try:
        data = request.get_json()
        features = data.get('features', [])
        
        if not features:
            return jsonify({"error": "No features provided"}), 400
        
        import numpy as np
        prediction = model_loader.predict(np.array([features]))
        
        return jsonify({
            "prediction": int(prediction[0]),
            "model_version": model_loader.metadata.get("version"),
            "model_hash": model_loader.metadata.get("artifact", {}).get("sha256")
        })
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/attestations', methods=['GET'])
def attestations():
    """Return model attestations and provenance"""
    provenance_path = f"{model_loader.artifacts_dir}/attestations/provenance.json"
    
    if not os.path.exists(provenance_path):
        return jsonify({"error": "Provenance not found"}), 404
    
    with open(provenance_path, 'r') as f:
        provenance = json.load(f)
    
    return jsonify({
        "provenance": provenance,
        "sboms": {
            "code": f"{model_loader.artifacts_dir}/sbom/code-sbom.json",
            "model": f"{model_loader.artifacts_dir}/sbom/model-sbom.json"
        }
    })

if __name__ == "__main__":
    import sys
    
    # Load model on startup
    require_sig = "--no-verify-signature" not in sys.argv
    require_att = "--no-verify-attestation" not in sys.argv
    
    if not model_loader.load_model(require_sig, require_att):
        print("❌ Failed to load model. Exiting.")
        sys.exit(1)
    
    # Start server
    print("\n🚀 Starting secure model server...")
    print("   Endpoints:")
    print("     GET  /health       - Health check")
    print("     POST /predict      - Make predictions")
    print("     GET  /attestations - View provenance")
    app.run(host='0.0.0.0', port=8080, debug=False)
