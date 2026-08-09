# ─────────────────────────────────────────────────────────────────────────────
# Governance Module: Model Versioning & Artifact Tracking
# ─────────────────────────────────────────────────────────────────────────────
# ValidatingPolicy (CEL, Kyverno 1.18 schema) enforcing model metadata on
# ML deployments: version labels on the Deployment and attestation references
# (SHA256, SBOM, provenance) as Pod template annotations.
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

resource "kubectl_manifest" "require_model_metadata" {
  yaml_body = yamlencode({
    apiVersion = "policies.kyverno.io/v1"
    kind       = "ValidatingPolicy"
    metadata = {
      name = "require-model-attestations"
      annotations = {
        "policies.kyverno.io/title"       = "Require Model Metadata"
        "policies.kyverno.io/category"    = "ML Security"
        "policies.kyverno.io/severity"    = "high"
        "policies.kyverno.io/description" = "Enforces required metadata on ML model deployments for version tracking and audit trails"
      }
    }
    spec = {
      failurePolicy     = "Fail"
      validationActions = ["Deny"]
      matchConstraints = {
        resourceRules = [
          {
            apiGroups   = ["apps"]
            apiVersions = ["v1"]
            operations  = ["CREATE", "UPDATE"]
            resources   = ["deployments"]
          }
        ]
      }
      matchConditions = [
        {
          name       = "is-ml-model"
          expression = "'app.kubernetes.io/component' in object.metadata.?labels.orValue({}) && object.metadata.labels['app.kubernetes.io/component'] == 'ml-model'"
        }
      ]
      validations = [
        {
          expression = "object.metadata.?labels.orValue({})['app.kubernetes.io/name'].size() > 0"
          message    = "ML model deployment must have label: app.kubernetes.io/name"
        },
        {
          expression = "object.metadata.?labels.orValue({})['app.kubernetes.io/version'].size() > 0"
          message    = "ML model deployment must have label: app.kubernetes.io/version"
        },
        {
          expression = "object.spec.?template.metadata.?annotations.orValue({})['ml.model/sha256'].size() > 0"
          message    = "ML model deployment pod template must have annotation: ml.model/sha256 (artifact hash)"
        },
        {
          expression = "object.spec.?template.metadata.?annotations.orValue({})['ml.model/sbom-ref'].size() > 0"
          message    = "ML model deployment pod template must have annotation: ml.model/sbom-ref (SBOM attestation reference)"
        },
        {
          expression = "object.spec.?template.metadata.?annotations.orValue({})['ml.model/provenance-ref'].size() > 0"
          message    = "ML model deployment pod template must have annotation: ml.model/provenance-ref (provenance attestation reference)"
        }
      ]
    }
  })

  depends_on = [var.helm_release_id]
}
