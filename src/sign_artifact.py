#!/usr/bin/env python3
"""
Artifact Signing with Cosign
Signs model artifacts and attestations using cosign keyless or key-based signing
"""

import os
import subprocess
import json
import hashlib
from typing import Dict, Any, Optional


class CosignSigner:
    """Wrapper for cosign signing operations"""
    
    def __init__(self, keyless: bool = False):
        """
        Initialize cosign signer
        
        Args:
            keyless: Use keyless signing with OIDC (requires interactive auth)
        """
        self.keyless = keyless
        self.verify_cosign_installed()
    
    def verify_cosign_installed(self):
        """Check if cosign is installed"""
        try:
            result = subprocess.run(
                ["cosign", "version"],
                capture_output=True,
                text=True,
                check=True
            )
            print(f"✅ Cosign found: {result.stdout.strip()}")
        except FileNotFoundError:
            raise RuntimeError(
                "❌ Cosign not found. Install from: https://docs.sigstore.dev/cosign/installation/"
            )
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"❌ Error checking cosign: {e}")
    
    def generate_keypair(self, output_dir: str = "keys"):
        """Generate a cosign key pair for signing"""
        if self.keyless:
            print("⏭️  Keyless mode enabled, skipping key generation")
            return
        
        os.makedirs(output_dir, exist_ok=True)
        key_path = f"{output_dir}/cosign.key"
        
        if os.path.exists(key_path):
            print(f"⚠️  Key already exists at {key_path}")
            return key_path
        
        print("🔑 Generating cosign keypair...")
        print("   You will be prompted for a password")
        
        try:
            subprocess.run(
                ["cosign", "generate-key-pair"],
                cwd=output_dir,
                check=True
            )
            print(f"✅ Keys generated in {output_dir}/")
            print(f"   Private key: {key_path}")
            print(f"   Public key: {key_path}.pub")
            return key_path
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"❌ Failed to generate keys: {e}")
    
    def sign_blob(
        self,
        file_path: str,
        output_signature: Optional[str] = None,
        key_path: Optional[str] = None
    ) -> str:
        """
        Sign a file blob with cosign (v3+ uses bundle format)
        
        Args:
            file_path: Path to file to sign
            output_signature: Path for bundle output (default: file_path.bundle)
            key_path: Path to private key (required if not keyless)
        
        Returns:
            Path to bundle file
        """
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"File not found: {file_path}")
        
        # Cosign v3+ uses bundle format instead of separate signature
        output_bundle = output_signature or f"{file_path}.bundle"
        
        print(f"✍️  Signing {file_path}...")
        
        if self.keyless:
            # Keyless signing with OIDC
            cmd = [
                "cosign", "sign-blob",
                file_path,
                "--bundle", output_bundle,
                "--yes"  # Auto-confirm
            ]
        else:
            # Key-based signing
            if not key_path:
                key_path = "keys/cosign.key"
            
            if not os.path.exists(key_path):
                raise FileNotFoundError(f"Private key not found: {key_path}")
            
            cmd = [
                "cosign", "sign-blob",
                file_path,
                "--key", key_path,
                "--bundle", output_bundle
            ]
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True
            )
            print(f"✅ Signature bundle saved to {output_bundle}")
            return output_bundle
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"❌ Signing failed: {e.stderr}")
    
    def verify_blob(
        self,
        file_path: str,
        bundle_path: str,
        key_path: Optional[str] = None
    ) -> bool:
        """
        Verify a signed blob using bundle (Cosign v3+)
        
        Args:
            file_path: Path to signed file
            bundle_path: Path to signature bundle
            key_path: Path to public key (required if not keyless)
        
        Returns:
            True if verification succeeds
        """
        print(f"🔍 Verifying {file_path}...")
        
        if self.keyless:
            # Keyless verification requires certificate and identity info
            print("⚠️  Keyless verification requires additional certificate info")
            return False
        else:
            if not key_path:
                key_path = "keys/cosign.pub"
            
            if not os.path.exists(key_path):
                raise FileNotFoundError(f"Public key not found: {key_path}")
            
            cmd = [
                "cosign", "verify-blob",
                file_path,
                "--key", key_path,
                "--bundle", bundle_path
            ]
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True
            )
            print(f"✅ Signature verified successfully!")
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ Verification failed: {e.stderr}")
            return False
    
    def attest(
        self,
        artifact_path: str,
        predicate_path: str,
        predicate_type: str = "https://slsa.dev/provenance/v0.2",
        key_path: Optional[str] = None
    ) -> str:
        """
        Create and sign an in-toto attestation
        
        Args:
            artifact_path: Path to artifact being attested
            predicate_path: Path to predicate JSON
            predicate_type: Type of predicate
            key_path: Path to private key
        
        Returns:
            Path to attestation file
        """
        output_attestation = f"{artifact_path}.att"
        
        print(f"📜 Creating attestation for {artifact_path}...")
        
        if self.keyless:
            cmd = [
                "cosign", "attest-blob",
                artifact_path,
                "--predicate", predicate_path,
                "--type", predicate_type,
                "--yes"
            ]
        else:
            if not key_path:
                key_path = "keys/cosign.key"
            
            cmd = [
                "cosign", "attest-blob",
                artifact_path,
                "--predicate", predicate_path,
                "--type", predicate_type,
                "--key", key_path
            ]
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True
            )
            
            # Save attestation to file
            with open(output_attestation, 'w') as f:
                f.write(result.stdout)
            
            print(f"✅ Attestation saved to {output_attestation}")
            return output_attestation
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"❌ Attestation failed: {e.stderr}")


def sign_model_artifacts(artifacts_dir: str = "artifacts", keyless: bool = False):
    """
    Sign all model artifacts and attestations
    
    Args:
        artifacts_dir: Directory containing model artifacts
        keyless: Use keyless signing
    """
    print("\n🔐 Starting artifact signing process...\n")
    
    signer = CosignSigner(keyless=keyless)
    
    # Generate keys if not keyless
    if not keyless:
        signer.generate_keypair()
    
    # Sign model artifact
    model_path = f"{artifacts_dir}/model.pkl"
    if os.path.exists(model_path):
        signer.sign_blob(model_path)
    
    # Sign SBOMs
    for sbom_file in ["code-sbom.json", "model-sbom.json"]:
        sbom_path = f"{artifacts_dir}/sbom/{sbom_file}"
        if os.path.exists(sbom_path):
            signer.sign_blob(sbom_path)
    
    # Sign provenance
    provenance_path = f"{artifacts_dir}/attestations/provenance.json"
    if os.path.exists(provenance_path):
        signer.sign_blob(provenance_path)
    
    print("\n✨ All artifacts signed successfully!")
    print("\n⚠️  IMPORTANT: Store the private key (keys/cosign.key) securely!")
    print("   The public key (keys/cosign.pub) should be distributed for verification.")


if __name__ == "__main__":
    import sys
    
    keyless = "--keyless" in sys.argv
    artifacts_dir = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "artifacts"
    
    sign_model_artifacts(artifacts_dir, keyless)
