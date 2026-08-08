# ─────────────────────────────────────────────────────────────────────────────
# Kyverno Policy Engine - Helm Release
# ─────────────────────────────────────────────────────────────────────────────
# Chart: 3.8.2 (Kyverno v1.18.2)
# Manages policy engine via Helm for proper CRD installation and upgrades
# ─────────────────────────────────────────────────────────────────────────────

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

resource "helm_release" "kyverno" {
  name = "kyverno"
  # Vendored chart (kyverno-3.8.2.tgz, sha256 f4fc787c...) pinned to Kyverno
  # v1.18.2. Local archive avoids flaky chart-server downloads during apply.
  chart            = "charts/kyverno-3.8.2.tgz"
  version          = "3.8.2" # Maps to Kyverno v1.18.2
  namespace        = kubernetes_namespace.kyverno.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      admissionController = {
        replicas = 2
        serviceAccount = {
          name = "kyverno-admission-controller"
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.kyverno_ecr.arn
          }
        }
      }
      backgroundController = {
        replicas = 1
        serviceAccount = {
          name = "kyverno-background-controller"
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.kyverno_ecr.arn
          }
        }
      }
      cleanupController = {
        replicas = 1
      }
      reportsController = {
        replicas = 1
      }
      # Disable deprecated ClusterPolicy support
      features = {
        policyExceptions = {
          enabled = true
        }
      }
    })
  ]

  depends_on = [
    module.eks,
    kubernetes_namespace.kyverno
  ]
}

# ─────────────────────────────────────────────────────────────────────────────
# IRSA annotations for Kyverno ServiceAccounts.
# Helm won't patch SAs created by earlier chart revisions, so these resources
# re-apply the annotation idempotently. Pods must be restarted once after the
# first annotation so the projected EKS token is mounted.
# ─────────────────────────────────────────────────────────────────────────────
resource "kubernetes_annotations" "kyverno_admission_sa" {
  api_version = "v1"
  kind        = "ServiceAccount"

  metadata {
    name      = "kyverno-admission-controller"
    namespace = kubernetes_namespace.kyverno.metadata[0].name
  }
  annotations = {
    "eks.amazonaws.com/role-arn" = aws_iam_role.kyverno_ecr.arn
  }

  force = true
}

resource "kubernetes_annotations" "kyverno_background_sa" {
  api_version = "v1"
  kind        = "ServiceAccount"

  metadata {
    name      = "kyverno-background-controller"
    namespace = kubernetes_namespace.kyverno.metadata[0].name
  }
  annotations = {
    "eks.amazonaws.com/role-arn" = aws_iam_role.kyverno_ecr.arn
  }

  force = true
}
