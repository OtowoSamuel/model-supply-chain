# Kyverno Installation Fix - Manual Commands

## Current Issue
The Kyverno namespace exists but has no pods running. The kubectl-based installation failed due to Kubernetes 1.33 annotation size limits (262144 bytes).

## Solution
Reinstall Kyverno using Helm, which handles the annotation size issue properly.

## Commands to Run

### Step 1: Delete the broken installation
```bash
# Delete CRDs (if any exist)
kubectl delete crds -l app.kubernetes.io/name=kyverno --ignore-not-found=true

# Delete the namespace
kubectl delete namespace kyverno
```

### Step 2: Wait for cleanup (optional - check if namespace is gone)
```bash
kubectl get namespace kyverno
# Should return "NotFound" error when ready
```

### Step 3: Install Kyverno via Helm
```bash
# Add Helm repo
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update kyverno

# Install Kyverno (version 1.12.x for EKS 1.33 compatibility)
helm install kyverno kyverno/kyverno \
    --namespace kyverno \
    --create-namespace \
    --version "~1.12.0" \
    --set admissionController.replicas=2 \
    --set backgroundController.replicas=1 \
    --set cleanupController.replicas=1 \
    --set reportsController.replicas=1 \
    --wait \
    --timeout 5m
```

### Step 4: Verify installation
```bash
# Check Helm release
helm list -n kyverno

# Check pods
kubectl get pods -n kyverno

# Check CRDs
kubectl get crds | grep kyverno | head -10

# Check for ClusterPolicy CRD
kubectl get crds clusterpolicies.kyverno.io
```

### Step 5: Apply policies
```bash
kubectl apply -f k8s/kyverno-policy.yaml
```

### Step 6: Continue with the pipeline
```bash
./scripts/setup-and-test-full-pipeline.sh
```

## Quick Fix Script
Alternatively, run the automated fix script:
```bash
chmod +x scripts/fix-kyverno-installation.sh
./scripts/fix-kyverno-installation.sh
```

## Why Helm instead of kubectl?
- Helm manages large CRD annotations better
- Helm splits large resources across multiple API calls
- Helm provides easier upgrades and rollbacks
- Helm is the recommended production installation method for Kyverno

## Expected Result
After installation you should see:
- 4 Kyverno pods running (admission-controller x2, background-controller, cleanup-controller, reports-controller)
- ~18 Kyverno CRDs installed including `clusterpolicies.kyverno.io`
- Policies successfully applied with `kubectl apply -f k8s/kyverno-policy.yaml`
