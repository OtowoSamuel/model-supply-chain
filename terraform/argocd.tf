# -----------------------------------------------------------------------------
# GitOps: Argo CD deploys the ml-staging workload from git (k8s/ directory).
# CI/CD no longer kubectl-applies directly; the build job commits the manifest
# and ArgoCD syncs it (polling-based; no webhook needed).
# -----------------------------------------------------------------------------

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name = "argocd"
  # Vendored chart (argo-cd-7.8.13.tgz) pinned; avoids chart-server flakiness.
  chart            = "charts/argo-cd-7.8.13.tgz"
  version          = "7.8.13"
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      configs = {
        params = {
          # ArgoCD serves the UI over the LB port directly (no TLS termination)
          "server.insecure" = true
        }
      }
      server = {
        service = {
          type = "LoadBalancer"
        }
      }
    })
  ]

  depends_on = [
    module.eks,
    kubernetes_namespace.argocd
  ]
}

# The single Application: syncs k8s/deployment.yaml from the repo into the
# cluster. ImageValidatingPolicy/audit mutations run on whatever ArgoCD
# applies, so the verification story is unchanged.
resource "kubectl_manifest" "ml_staging_app" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "ml-staging"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/OtowoSamuel/model-supply-chain"
        targetRevision = "main"
        path           = "k8s"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "ml-staging"
      }
      # ignoreDifferences: kyverno's inject-audit-trail mutation stamps
      # audit annotations on every apply; otherwise selfHeal would fight it.
      ignoreDifferences = [
        {
          group = ""
          kind  = "Namespace"
          jqPathExpressions = [
            ".metadata.annotations"
          ]
        },
        {
          group = "apps"
          kind  = "Deployment"
          jqPathExpressions = [
            ".metadata.annotations"
          ]
        }
      ]
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  })

  depends_on = [helm_release.argocd]
}
