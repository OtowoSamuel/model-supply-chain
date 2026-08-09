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
      # Kyverno v1.18 resolves registry credentials from the --imagePullSecrets
      # flag (pull secrets) only; IRSA is not consulted for image verification.
      # Secret kyverno-ecr-registry is created + refreshed by the external-secrets
      # ECR generator (ECR auth tokens expire every 12h).
      existingImagePullSecrets = ["kyverno-ecr-registry"]
      # Disable deprecated ClusterPolicy support + log verbosity via Helm
      # (previously set by an out-of-band kubectl patch, --v=6, which got lost
      # on every helm upgrade).
      features = {
        logging = {
          # Logging verbosity (--v)
          verbosity = 6
        }
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

# ─────────────────────────────────────────────────────────────────────────────
# ECR registry credentials for Kyverno image verification.
# Kyverno v1.18 fetches registry credentials from the --imagePullSecrets flag,
# i.e. a kubernetes.io/dockerconfigjson Secret in the kyverno namespace. ECR
# authorization tokens expire after 12h, so the Secret is refreshed by
# external-secrets (ECR generator) below instead of a hand-rolled CronJob.
# The Secret itself is owned by the ExternalSecret resource (not managed
# directly by terraform) so applies never clobber the live token.
# ─────────────────────────────────────────────────────────────────────────────

resource "helm_release" "external_secrets" {
  name = "external-secrets"
  # Vendored chart (external-secrets-2.9.0.tgz) pinned like Kyverno to avoid
  # flaky chart-server downloads during apply.
  chart            = "charts/external-secrets-2.9.0.tgz"
  version          = "2.9.0"
  namespace        = "external-secrets"
  create_namespace = true
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      serviceAccount = {
        name = "external-secrets"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.kyverno_ecr.arn
        }
      }
    })
  ]

  depends_on = [
    module.eks,
    kubernetes_namespace.kyverno
  ]
}

resource "kubernetes_annotations" "external_secrets_sa" {
  api_version = "v1"
  kind        = "ServiceAccount"

  metadata {
    name      = "external-secrets"
    namespace = "external-secrets"
  }
  annotations = {
    "eks.amazonaws.com/role-arn" = aws_iam_role.kyverno_ecr.arn
  }

  force = true
}

# SA for the ECR generator's jwt auth (looked up in the generator's namespace)
resource "kubectl_manifest" "kyverno_ecr_sa" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name      = "external-secrets"
      namespace = kubernetes_namespace.kyverno.metadata[0].name
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.kyverno_ecr.arn
      }
    }
  })

  depends_on = [helm_release.external_secrets]
}

# ECRAuthorizationToken generator (free token, 12h expiry)
resource "kubectl_manifest" "ecr_auth_token_generator" {
  yaml_body = yamlencode({
    apiVersion = "generators.external-secrets.io/v1alpha1"
    kind       = "ECRAuthorizationToken"
    metadata = {
      name      = "kyverno-ecr-token"
      namespace = "kyverno"
    }
    spec = {
      region = var.aws_region
      # jwt: SA resolved in the generator's own namespace (kyverno), IRSA -> kyverno-ecr role
      auth = {
        jwt = {
          serviceAccountRef = {
            name = "external-secrets"
          }
        }
      }
    }
  })

  depends_on = [helm_release.external_secrets]
}

# ExternalSecret -> kubernetes.io/dockerconfigjson Secret for Kyverno
resource "kubectl_manifest" "kyverno_ecr_registry_secret" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "kyverno-ecr-registry"
      namespace = kubernetes_namespace.kyverno.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      target = {
        name       = "kyverno-ecr-registry"
        secretType = "kubernetes.io/dockerconfigjson"
        template = {
          type = "kubernetes.io/dockerconfigjson"
          data = {
            ".dockerconfigjson" = <<-EOT
              {"auths":{"{{ .proxy_endpoint }}":{"username":"{{ .username }}","password":"{{ .password }}","auth":"{{ printf "%s:%s" .username .password | b64enc }}"}}}
            EOT
          }
        }
      }
      dataFrom = [
        {
          sourceRef = {
            generatorRef = {
              apiVersion = "generators.external-secrets.io/v1alpha1"
              kind       = "ECRAuthorizationToken"
              name       = "kyverno-ecr-token"
            }
          }
        }
      ]
    }
  })

  depends_on = [helm_release.external_secrets]
}
