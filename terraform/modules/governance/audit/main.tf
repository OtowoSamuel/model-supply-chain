# ─────────────────────────────────────────────────────────────────────────────
# Governance Module: Audit Trail & Logging
# ─────────────────────────────────────────────────────────────────────────────
# 1. MutatingPolicy (CEL, Kyverno 1.18 schema) injecting audit annotations
#    on Deployments: deployed-at timestamp, operator identity, request id.
# 2. ValidatingPolicy (Audit mode) requiring a SLSA provenance reference on
#    production ML deployments.
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

resource "kubectl_manifest" "inject_audit_metadata" {
  yaml_body = yamlencode({
    apiVersion = "policies.kyverno.io/v1"
    kind       = "MutatingPolicy"
    metadata = {
      name = "inject-audit-trail"
      annotations = {
        "policies.kyverno.io/title"       = "Inject Audit Trail Metadata"
        "policies.kyverno.io/category"    = "Audit & Compliance"
        "policies.kyverno.io/severity"    = "medium"
        "policies.kyverno.io/description" = "Automatically injects audit trail annotations for traceability"
      }
    }
    spec = {
      matchConstraints = {
        resourceRules = [
          {
            apiGroups   = ["apps"]
            apiVersions = ["v1"]
            operations  = ["CREATE", "UPDATE"]
            resources   = ["deployments"]
            namespaces  = ["ml-production", "ml-staging"]
          }
        ]
      }
      mutations = [
        {
          patchType = "ApplyConfiguration"
          applyConfiguration = {
            expression = <<-EOT
              has(object.metadata.annotations) ?
              Object{
                metadata: Object.metadata{
                  annotations: Object.metadata.annotations{
                    "audit.ml-supply-chain/deployed-at": string(time.now()),
                    "audit.ml-supply-chain/deployed-by-user": request.userInfo.username,
                    "audit.ml-supply-chain/deployed-by-uid": request.userInfo.uid,
                    "audit.ml-supply-chain/admission-request-id": request.uid,
                    "audit.ml-supply-chain/operation": request.operation
                  }
                }
              } :
              Object{
                metadata: Object.metadata{
                  annotations: {
                    "audit.ml-supply-chain/deployed-at": string(time.now()),
                    "audit.ml-supply-chain/deployed-by-user": request.userInfo.username,
                    "audit.ml-supply-chain/deployed-by-uid": request.userInfo.uid,
                    "audit.ml-supply-chain/admission-request-id": request.uid,
                    "audit.ml-supply-chain/operation": request.operation
                  }
                }
              }
            EOT
          }
        }
      ]
    }
  })

  depends_on = [var.helm_release_id]
}

resource "kubectl_manifest" "slsa_provenance_audit" {
  yaml_body = yamlencode({
    apiVersion = "policies.kyverno.io/v1"
    kind       = "ValidatingPolicy"
    metadata = {
      name = "enforce-slsa-level"
      annotations = {
        "policies.kyverno.io/title"       = "Enforce Minimum SLSA Level"
        "policies.kyverno.io/category"    = "Supply Chain Security"
        "policies.kyverno.io/severity"    = "high"
        "policies.kyverno.io/description" = "Production deployments require SLSA provenance logged to transparency log"
      }
    }
    spec = {
      failurePolicy     = "Fail"
      validationActions = ["Audit"] # Audit mode - logs violations without blocking
      matchConstraints = {
        resourceRules = [
          {
            apiGroups   = ["apps"]
            apiVersions = ["v1"]
            operations  = ["CREATE", "UPDATE"]
            resources   = ["deployments"]
            namespaces  = ["ml-production"]
          }
        ]
      }
      validations = [
        {
          expression = "object.spec.?template.metadata.?annotations.orValue({})['ml.model/provenance-ref'].size() > 0"
          message    = "Production deployment is missing SLSA provenance reference. Verify attestation is signed and stored in Rekor transparency log."
        }
      ]
    }
  })

  depends_on = [var.helm_release_id]
}
