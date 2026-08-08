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
      # Secret kyverno-ecr-registry is created + refreshed by the rotation
      # CronJob below (ECR auth tokens expire every 12h).
      existingImagePullSecrets = ["kyverno-ecr-registry"]
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

# ─────────────────────────────────────────────────────────────────────────────
# ECR registry credentials for Kyverno image verification.
# Kyverno v1.18 fetches registry credentials from the --imagePullSecrets flag,
# i.e. a kubernetes.io/dockerconfigjson Secret in the kyverno namespace. ECR
# authorization tokens expire after 12h. The Secret is created and refreshed
# ONLY by the rotation CronJob below (hourly, using the same IRSA role); it is
# intentionally NOT managed by terraform so applies can never clobber the live
# token with a stale placeholder.
# ─────────────────────────────────────────────────────────────────────────────

resource "kubernetes_service_account_v1" "kyverno_ecr_rotation" {
  metadata {
    name      = "kyverno-ecr-rotation"
    namespace = kubernetes_namespace.kyverno.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.kyverno_ecr.arn
    }
  }
}

resource "kubernetes_role_v1" "kyverno_ecr_rotation" {
  metadata {
    name      = "kyverno-ecr-rotation"
    namespace = kubernetes_namespace.kyverno.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch", "create", "patch", "update"]
  }
}

resource "kubernetes_role_binding_v1" "kyverno_ecr_rotation" {
  metadata {
    name      = "kyverno-ecr-rotation"
    namespace = kubernetes_namespace.kyverno.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.kyverno_ecr_rotation.metadata[0].name
    namespace = kubernetes_namespace.kyverno.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.kyverno_ecr_rotation.metadata[0].name
  }
}

resource "kubernetes_cron_job_v1" "kyverno_ecr_rotation" {
  metadata {
    name      = "kyverno-ecr-rotation"
    namespace = kubernetes_namespace.kyverno.metadata[0].name
  }

  spec {
    schedule                      = "0 * * * *"
    concurrency_policy            = "Forbid"
    starting_deadline_seconds     = 300
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 2
    job_template {
      metadata {
        name      = "kyverno-ecr-rotation"
        namespace = kubernetes_namespace.kyverno.metadata[0].name
      }
      spec {
        backoff_limit = 2
        template {
          metadata {
            labels = {
              app = "kyverno-ecr-rotation"
            }
          }
          spec {
            service_account_name            = kubernetes_service_account_v1.kyverno_ecr_rotation.metadata[0].name
            restart_policy                  = "OnFailure"
            active_deadline_seconds         = 240
            automount_service_account_token = "true"

            init_container {
              name    = "fetch-ecr-token"
              image   = "amazon/aws-cli:2.16.0"
              command = ["/bin/sh", "-c"]
              args = [
                "TOKEN=$(aws ecr get-authorization-token --region us-east-1 --output text | cut -f2) && printf '{\"auths\":{\"https://${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com\":{\"auth\":\"%s\"},\"${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com\":{\"auth\":\"%s\"}}}' \"$TOKEN\" \"$TOKEN\" > /tmp/ecr-config/dockerconfig.json && echo ROTATE_OK"
              ]
              volume_mount {
                name       = "ecr-config"
                mount_path = "/tmp/ecr-config"
              }
            }

            container {
              name    = "push-ecr-secret"
              image   = "bitnamilegacy/kubectl:1.31.4"
              command = ["/bin/sh", "-c"]
              args = [
                "TOKEN=$(base64 -w0 /tmp/ecr-config/dockerconfig.json) && kubectl -n kyverno create secret docker-registry kyverno-ecr-registry --dry-run=client --from-file=.dockerconfigjson=/tmp/ecr-config/dockerconfig.json -o yaml | kubectl apply -f -"
              ]
              volume_mount {
                name       = "ecr-config"
                mount_path = "/tmp/ecr-config"
              }
            }

            volume {
              name = "ecr-config"
              empty_dir {}
            }
          }
        }
      }
    }
  }
}
