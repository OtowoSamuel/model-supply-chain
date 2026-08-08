# Kyverno Migration Changelog

## Changes Made

### 1. Helm Management (terraform/kyverno.tf)
- **Added**: `helm_release` resource for Kyverno
- **Chart Version**: 3.8.2 (Kyverno v1.18.2)
- **Provider**: Added `helm` provider with EKS authentication
- **Configuration**: 2 admission controllers, 1 each for background/cleanup/reports

### 2. Provider Updates (terraform/main.tf)
- **Added**: `helm` provider (~> 2.13)
- **Added**: `kubectl` provider (~> 1.14) for CRD management
- **Added**: `kubectl` provider configuration with EKS auth

### 3. Policy Migration (ClusterPolicy → CEL-based types)

#### Approvals Module (modules/governance/approvals/)
- **Old**: `ClusterPolicy` with `verifyImages` + JMESPath conditions
- **New**: `ImageValidatingPolicy` (policies.kyverno.io/v1)
- **Changes**:
  - Native image verification policy type
  - Added ECR pattern: `*.dkr.ecr.*.amazonaws.com/*/model-server*`
  - Streamlined attestation structure
  - No SSRF risk (uses native Cosign, no apiCall)

#### Versioning Module (modules/governance/versioning/)
- **Old**: `ClusterPolicy` with `validate.pattern` (JMESPath)
- **New**: `ValidatingPolicy` with CEL expressions
- **Changes**:
  - 5 separate CEL validations (one per required label)
  - CEL syntax: `has(object.metadata.labels) && size(...) > 0`
  - More explicit error messages per missing label
  - No SSRF risk (no external calls)

#### Audit Module (modules/governance/audit/)
- **Old**: `ClusterPolicy` with `validate.manifests` (unclear structure)
- **New**: 
  - `MutatingPolicy` for audit annotation injection
  - `ValidatingPolicy` for SLSA enforcement (Audit mode)
- **Changes**:
  - Audit injection uses `patchStrategicMerge` with timestamp/user
  - SLSA check in Audit mode (non-blocking, logs violations)
  - No SSRF risk (no external calls)

### 4. Module Structure
- **Created**: `modules/governance/{approvals,versioning,audit}/`
- **Pattern**: Each module takes `helm_release_id` for ordering
- **Invocation**: Added module calls in `main.tf` after namespaces

### 5. Removed Files
- **k8s/kyverno-policy.yaml**: Replaced by Terraform-managed policies
  - Delete this file or keep as reference only
  - Policies now in Terraform modules

## Breaking Changes

### Required Actions

1. **Terraform State Migration**
   ```bash
   cd terraform
   terraform init -upgrade  # Install new providers
   ```

2. **Delete Manual Kyverno Installation**
   ```bash
   helm uninstall kyverno -n kyverno
   kubectl delete namespace kyverno
   ```

3. **Apply New Infrastructure**
   ```bash
   terraform apply
   ```

4. **Update Setup Script**
   - Remove Kyverno Helm install section from `scripts/setup-and-test-full-pipeline.sh`
   - Kyverno is now managed by Terraform

5. **Delete Old Policy File**
   ```bash
   # No longer needed - policies in Terraform
   rm k8s/kyverno-policy.yaml  # or keep as .bak
   ```

## CVE Analysis

### CVE-2026-4789 & CVE-2026-41323 (SSRF)
- **Affected Feature**: `apiCall` and HTTP context variables
- **Our Usage**: ✅ **NOT AFFECTED**
  - ImageValidatingPolicy uses native Cosign verification (no HTTP)
  - ValidatingPolicy uses CEL expressions (no external calls)
  - MutatingPolicy uses local patches (no external calls)
  - No policies use `apiCall` or HTTP variables

## Testing Checklist

- [ ] `terraform init -upgrade` succeeds
- [ ] `terraform plan` shows Helm release + 4 policy resources
- [ ] `terraform apply` completes without errors
- [ ] `helm list -n kyverno` shows kyverno release
- [ ] `kubectl get validatingpolicies,mutatingpolicies,imagevalidatingpolicies` shows 4 policies
- [ ] Deploy test ML workload without labels → should fail versioning check
- [ ] Deploy test ML workload with labels → should get audit annotations
- [ ] Check policy reports: `kubectl get policyreports -A`

## Rollback Plan

If issues occur:
```bash
cd terraform
terraform destroy -target=module.governance_approvals
terraform destroy -target=module.governance_versioning
terraform destroy -target=module.governance_audit
terraform destroy -target=helm_release.kyverno

# Manual Helm reinstall
helm install kyverno kyverno/kyverno --namespace kyverno --create-namespace
kubectl apply -f k8s/kyverno-policy.yaml.bak
```
