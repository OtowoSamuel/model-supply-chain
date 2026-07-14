# Key Concepts Explained (ELI12)

## 📚 Table of Contents

1. [What is OPA?](#what-is-opa)
2. [What is Kyverno?](#what-is-kyverno)
3. [What is SLSA Provenance?](#what-is-slsa-provenance)
4. [What is Cosign?](#what-is-cosign)
5. [What is SBOM?](#what-is-sbom)

---

## 🚦 What is OPA?

**OPA = Open Policy Agent** - A rules checker for your security policies

### Simple Explanation
OPA is like a **bouncer at a nightclub** checking IDs:
- You write rules (must be 21+, valid ID, on guest list)
- OPA checks if something meets those rules
- Says "allowed ✅" or "denied ❌"

### Real Example
```rego
# Your rules in OPA
allow if {
    model_is_signed ✓
    accuracy >= 85% ✓
    no_viruses ✓
}
```

### When It Runs
**Before deployment** - stops bad models from going live

---

## 🛡️ What is Kyverno?

**Kyverno** - Security guard for Kubernetes deployments

### Simple Explanation
Kyverno is like **TSA at the airport**:
- Checks every deployment trying to get on the "plane" (Kubernetes)
- Scans for banned items (unsigned images, no attestations)
- Blocks anything suspicious automatically

### Real Example
```yaml
# Kyverno policy
verifyImages:
  - imageReferences: ["ghcr.io/*/model-server*"]
    attestations:
      - predicateType: https://slsa.dev/provenance/v0.2
```

**Translation**: "Only allow model-server images that have SLSA provenance"

### When It Runs
**Automatically** when you deploy to Kubernetes

### Key Difference from OPA
| OPA | Kyverno |
|-----|---------|
| Works anywhere | Only Kubernetes |
| You call it manually | Runs automatically |
| General purpose | Kubernetes-specific |

---

## 🧾 What is SLSA Provenance?

**SLSA Provenance** = The receipt for your AI model

### Simple Explanation
Like a **diamond certificate** that proves:
- 💎 What: 2-carat diamond ring
- 👷 Who made it: Tiffany & Co.
- 📅 When: January 10, 2025
- 🏭 Where: New York factory
- 📦 Materials: Gold + diamond

**For AI models:**
- What was built: model.pkl
- Who built it: GitHub Actions
- When: 2025-01-13 10:30 UTC
- Where: github.com/user/repo@abc123
- Materials: scikit-learn, numpy, dataset-v1

### What's Inside
```json
{
  "builder": {"id": "github-actions"},
  "buildStartedOn": "2025-01-13T10:30:00Z",
  "parameters": {
    "n_estimators": 100,
    "dataset": "iris"
  },
  "materials": [
    {"uri": "pkg:pypi/scikit-learn@1.3.0"}
  ]
}
```

### Why You Need It
**Without provenance:**
- 🤷 Where did this model come from?
- 🤷 Can I trust it?
- 🤷 How do I reproduce it?

**With provenance:**
- ✅ Exact source and build process
- ✅ Can verify authenticity
- ✅ Can reproduce exactly

---

## ✍️ What is Cosign?

**Cosign** = Digital signature tool (like a wax seal)

### Simple Explanation
Remember medieval times when kings sealed letters with **hot wax + ring**?

Cosign does the **digital version**:
- Puts a "seal" on your AI model
- Proves it's from you
- Shows if anyone tampered with it

### How It Works

**Signing:**
```
Your model.pkl
    +
Your digital signature
    =
model.pkl.bundle (sealed!)
```

**Verifying:**
```
Someone else downloads model.pkl.bundle
    ↓
Checks the seal with your public key
    ↓
✅ Valid (not tampered) or ❌ Invalid (modified)
```

### Two Ways to Sign

**1. Key-based** (like a physical key)
```bash
cosign generate-key-pair
# Creates: private key (keep secret!) + public key (share)

cosign sign-blob model.pkl --key private.key
# Creates: model.pkl.bundle
```

**2. Keyless** (like Face ID - no keys!)
```bash
cosign sign-blob model.pkl --yes
# Uses your GitHub/Google identity
# Logs to public transparency log
```

### Why You Need It
- ✅ Proves authenticity
- ✅ Detects tampering instantly
- ✅ Non-repudiation (can't deny signing)

---

## 📦 What is SBOM?

**SBOM = Software Bill of Materials** - Ingredient list for software

### Simple Explanation
Like a **food nutrition label**:

```
Cereal Box:
━━━━━━━━━━━
INGREDIENTS:
- Oats
- Sugar
- Salt
- Vitamin B12

ALLERGENS:
Contains gluten
━━━━━━━━━━━
```

**For AI models:**
```
Model SBOM:
━━━━━━━━━━━
COMPONENTS:
- scikit-learn 1.3.0
- numpy 1.24.0
- flask 3.0.0

VULNERABILITIES:
None found
━━━━━━━━━━━
```

### Two Types in Your Project

**1. Code SBOM** (software dependencies)
```json
{
  "components": [
    {"name": "scikit-learn", "version": "1.3.0"},
    {"name": "numpy", "version": "1.24.0"}
  ]
}
```

**2. Model SBOM** (ML-specific)
```json
{
  "components": [
    {
      "type": "machine-learning-model",
      "name": "fraud-detector",
      "accuracy": "0.92",
      "dataset": "customer-data-v1"
    }
  ]
}
```

### Why You Need It

**Scenario: Log4Shell vulnerability (Dec 2021)**

Without SBOM:
```
❓ Do we use Log4j?
❓ Which version?
❓ In which models?
Result: Weeks of manual searching 😫
```

With SBOM:
```bash
grep -r "log4j" */sbom/
model-v1/sbom.json: "log4j": "2.14.0"  ← Found it!
Result: Seconds ✅
```

### Real Use Cases

**1. Security Vulnerability**
```bash
# CVE found in numpy < 1.24.2
grep "numpy.*1.24.[01]" artifacts/sbom/*.json
# Found! Need to update
```

**2. License Compliance**
```bash
# Check for GPL licenses (can't use in commercial)
cat sbom.json | jq '.components[].licenses'
# Found GPL! Need to replace
```

**3. Supply Chain Attack**
```bash
# Malicious package on PyPI
grep "pytorch-nightly" sbom.json
# Not found? You're safe! ✅
```

---

## 🎯 How They Work Together

```
1. TRAIN MODEL
   └─> Creates SLSA provenance (receipt)

2. GENERATE SBOM
   └─> Lists all ingredients

3. SIGN WITH COSIGN
   └─> Puts wax seal on everything

4. OPA CHECKS
   └─> Is it signed? ✓
   └─> Has SBOM? ✓
   └─> Has provenance? ✓
   └─> Accuracy good? ✓

5. BUILD CONTAINER
   └─> Package everything

6. KYVERNO CHECKS (at deployment)
   └─> Is container signed? ✓
   └─> Has attestations? ✓

7. DEPLOY ✅
```

---

## 🆚 Quick Comparison

| Tool | What It Does | When It Runs |
|------|--------------|--------------|
| **Cosign** | Signs artifacts | During build |
| **SLSA** | Tracks provenance | During training |
| **SBOM** | Lists ingredients | After training |
| **OPA** | Checks policies | Before deployment |
| **Kyverno** | Guards Kubernetes | At deployment |

---

## 💡 Why All This?

### The Problem
Companies deploy AI with **zero security**:
- ❌ No signatures
- ❌ No ingredient lists
- ❌ No receipts
- ❌ No safety checks

**Result**: Anyone can tamper with your AI

### Your Solution
Every model has:
- ✅ Digital signature (Cosign)
- ✅ Receipt (SLSA provenance)
- ✅ Ingredient list (SBOM)
- ✅ Safety checks (OPA + Kyverno)

**Result**: Bulletproof supply chain security! 🔐

---

## 🎓 Summary (TL;DR)

- **Cosign** = Wax seal (proves authenticity)
- **SLSA** = Receipt (proves origin)
- **SBOM** = Ingredient list (shows what's inside)
- **OPA** = Bouncer (checks rules before entry)
- **Kyverno** = TSA (checks at the gate)

**Together** = Complete ML security system 🛡️

---

## 📖 Learn More

- **Deep dive**: See `/docs/technical/ARCHITECTURE.md`
- **Hands-on**: Run `./scripts/e2e-demo.sh`
- **Questions**: Check `/docs/FAQ.md`
