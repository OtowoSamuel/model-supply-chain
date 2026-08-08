# Kyverno Migration Changelog

Kyverno is now managed entirely through Terraform. ClusterPolicy / CleanupPolicy
(removed in v1.20) are gone; all policies are CEL-based types applied via the
`kubectl` provider with `depends_on` on the Helm release.

## What Changed and Why

### 1. Helm Management (terraform/kyverno.tf)
- `helm_release.kyverno` pinned to **chart 3.8.2 → Kyverno v1.18.2** (latest
  stable mapping to 1.18, verified live via `helm search repo kyverno/kyverno -l`).
- Controllers: admission x2, background/cleanup/reports x1 each (matches live cluster).
- Installs into the existing `kubernetes_namespace.kyverno` (already in state).
- No ClusterPolicy feature is enabled; policy types referenced are the CEL ones.

### 2. Policy Migration (ClusterPolicy/JMESPath → CEL types)
All migrated policies use `apiVersion: policies.kyverno.io/v1` and the Kyverno
**1.18** schema (`matchConstraints.resourceRules`, CEL `validations`/`mutations`).
The earlier draft used the 1.14-era manifest schema (`spec.match`, `verifyImages`,
`patchStrategicMerge`) which is not the shape the 1.18 CRDs expect — rewritten.

#### Approvals — `ImageValidatingPolicy verify-model-supply-chain`
- Native Sigstore keyless verification (GitHub Actions OIDC subject/issuer, Rekor CT log).
- `matchImageReferences`: `ghcr.io/*/model-server*` + `*.dkr.ecr.*.amazonaws.com/*/model-server*`.
- CEL validations over `images.containers`:
  `verifyImageSignatures`, `verifyAttestationSignatures` for SLSA
  (`https://slsa.dev/provenance/v0.2`) and CycloneDX SBOM attestations, plus
  payload checks (builder id, buildFinishedOn, bomFormat) via `extractPayload`.
- Applies to Pods and pod controllers (Deployments/StatefulSets/DaemonSets/ReplicaSets/Jobs/CronJobs) in `ml-production` and `ml-staging`.

#### Versioning (ValidatingPolicy `require-model-attestations`)
- CEL validations for required metadata, scoped via `matchConditions` to
  `app.kubernetes.io/component == ml-model` Deployments.
- Deployment labels: `app.kubernetes.io/name`, `app.kubernetes.io/version`.
- Pod template annotations: `ml.model/sha256`, `ml.model/sbom-ref`,
  `ml.model/provenance-ref`.
- **Deliberate fix**: the old policy required `ml.model/*` as Deployment labels,
  but in `k8s/deployment.yaml` they are pod template annotations. The CEL policy
  now checks the actual location.

#### Audit Trails (module `audit`)
- `MutatingPolicy inject-audit-trail` (new): injects
  `audit.ml-supply-chain/deployed-at` (`time.now()`), deployer user/uid
  (`request.userInfo`), admission request id and operation on Deployments in
  `ml-production`/`ml-staging`, via CEL `ApplyConfiguration` patch.
- `ValidatingPolicy enforce-slsa-level` (Audit mode, non-blocking): requires a
  `ml.model/provenance-ref` annotation on `ml-production` Deployments.

### 3. Provider Changes (terraform/versions.tf, main.tf)
- Added `hashicorp/helm` (~> 2.13) and `gavinbunney/kubectl` (~> 1.14) providers.
- Added helm/kubectl provider blocks wired to EKS exec auth.
- Governance modules wired in main.tf with `depends_on = helm_release.kyverno`.

### 4. Scripts / CI no longer install or apply Kyverno manually
- `scripts/fix-kyverno-installation.sh`: manual `helm install` removed → defers to `terraform apply`.
- `scripts/setup-and-test-full-pipeline.sh`: Step 4 now verifies the Terraform-managed install instead of installing Kyverno 1.12 / applying `kyverno-policy.yaml`.
- `.github/workflows/infra.yml`: removed `kubectl create -f .../install.yaml` + policy apply → verifies Terraform-installed Kyverno and the four CEL policies.
- `.github/workflows/model-pipeline.yml`: `Apply Kyverno policies` step → policy verification only.

### 5. Files
- `k8s/kyverno-policy.yaml` → renamed `k8s/kyverno-policy.yaml.bak` (old ClusterPolicy reference).
- Policies now live in `terraform/modules/governance/{approvals,versioning,audit}/main.tf`.

## SSRF CVE Status (CVE-2026-4789, CVE-2026-41323)

**Not affected.** Both CVEs are SSRF in Kyverno's `apiCall`/CEL HTTP context
features, patched in 1.18. None of the policies use `apiCall`, `http.Get()`,
`http.Post()`, or GlobalContext API entries — image verification is native
Sigstore (no HTTP fetch by Kyverno). Running 1.18.2 also means the patch is present.

## Verify Locally

```bash
cd terraform
terraform init            # needs hashicorp/helm + gavinbunney/kubectl providers
terraform plan            # should show helm_release.kyverno + 4 policy manifests
terraform apply
helm list -n kyverno      # kyverno chart 3.8.2 / app v1.18.2
kubectl get imagevalidatingpolicies,validatingpolicies,mutatingpolicies -A
```

## Rollback

```bash
cd terraform
terraform destroy -target=module.governance_approvals
terraform destroy -target=module.governance_versioning
terraform destroy -target=module.governance_audit
terraform destroy -target=helm_release.kyverno
```