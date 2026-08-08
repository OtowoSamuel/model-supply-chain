# ─────────────────────────────────────────────────────────────────────────────
# Governance Module: Deployment Approvals
# ─────────────────────────────────────────────────────────────────────────────
# ImageValidatingPolicy (CEL, Kyverno 1.18 schema) for ML image
# signature verification. Blocks deployments without valid Cosign keyless
# signatures and SLSA/CycloneDX attestations.
#
# NOTE: verifyImages/Cosign entry flow is native Sigstore (no apiCall/HTTP
# CEL library), so CVE-2026-4789 and CVE-2026-41323 (SSRF via apiCall/http)
# do not apply.
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

resource "kubectl_manifest" "verify_model_images" {
  yaml_body = yamlencode({
    apiVersion = "policies.kyverno.io/v1"
    kind       = "ImageValidatingPolicy"
    metadata = {
      name = "verify-model-supply-chain"
      annotations = {
        "policies.kyverno.io/title"       = "Verify Model Supply Chain Security"
        "policies.kyverno.io/category"    = "Supply Chain Security"
        "policies.kyverno.io/severity"    = "critical"
        "policies.kyverno.io/description" = "Enforces supply chain security for ML model deployments by verifying cosign signatures and SLSA/CycloneDX attestations"
      }
    }
    spec = {
      failurePolicy     = "Fail"
      validationActions = ["Deny"]
      webhookConfiguration = {
        timeoutSeconds = 15
      }
      matchConstraints = {
        resourceRules = [
          {
            apiGroups   = [""]
            apiVersions = ["v1"]
            operations  = ["CREATE", "UPDATE"]
            resources   = ["pods"]
            namespaces  = ["ml-production", "ml-staging"]
          },
          {
            apiGroups   = ["apps"]
            apiVersions = ["v1"]
            operations  = ["CREATE", "UPDATE"]
            resources   = ["deployments", "statefulsets", "daemonsets", "replicasets"]
            namespaces  = ["ml-production", "ml-staging"]
          },
          {
            apiGroups   = ["batch"]
            apiVersions = ["v1"]
            operations  = ["CREATE", "UPDATE"]
            resources   = ["jobs", "cronjobs"]
            namespaces  = ["ml-production", "ml-staging"]
          }
        ]
      }
      matchImageReferences = [
        { glob = "ghcr.io/*/model-server*" },
        { glob = "*.dkr.ecr.*.amazonaws.com/*/model-server*" }
      ]
      attestors = [
        {
          name = "cosign"
          cosign = {
            keyless = {
              identities = [
                {
                  subject = "https://github.com/*"
                  issuer  = "https://token.actions.githubusercontent.com"
                }
              ]
            }
            ctlog = {
              url = "https://rekor.sigstore.dev"
            }
          }
        }
      ]
      attestations = [
        {
          name = "slsa"
          intoto = {
            type = "https://slsa.dev/provenance/v0.2"
          }
        },
        {
          name = "sbom"
          intoto = {
            type = "https://cyclonedx.org/bom"
          }
        }
      ]
      validations = [
        {
          expression = "images.containers.map(image, verifyImageSignatures(image, [attestors.cosign])).all(e, e > 0)"
          message    = "Image is not signed with a valid Cosign keyless signature from GitHub Actions"
        },
        {
          expression = "images.containers.map(image, verifyAttestationSignatures(image, attestations.slsa, [attestors.cosign])).all(e, e > 0)"
          message    = "Image is missing a valid SLSA provenance attestation (https://slsa.dev/provenance/v0.2)"
        },
        {
          expression = "images.containers.map(image, verifyAttestationSignatures(image, attestations.sbom, [attestors.cosign])).all(e, e > 0)"
          message    = "Image is missing a valid CycloneDX SBOM attestation"
        },
        {
          expression = "images.containers.map(image, extractPayload(image, attestations.slsa).predicate.builder.id in ['github-actions', 'gitlab-ci']).all(e, e)"
          message    = "SLSA provenance must be built by github-actions or gitlab-ci"
        },
        {
          expression = "images.containers.map(image, extractPayload(image, attestations.slsa).predicate.metadata.buildFinishedOn != '').all(e, e)"
          message    = "SLSA provenance must include a buildFinishedOn timestamp"
        },
        {
          expression = "images.containers.map(image, extractPayload(image, attestations.sbom).bomFormat == 'CycloneDX').all(e, e)"
          message    = "SBOM attestation must be in CycloneDX format"
        }
      ]
    }
  })

  depends_on = [var.helm_release_id]
}
