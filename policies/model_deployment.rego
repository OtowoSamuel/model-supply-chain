package model.deployment

import future.keywords.if
import future.keywords.in

# Default deny - models must pass all checks
default allow = false

# Allow deployment if all security requirements are met
allow if {
    has_valid_signature
    has_valid_sbom
    has_slsa_provenance
    meets_quality_threshold
    no_critical_vulnerabilities
}

# Check 1: Model artifact must be signed with cosign
has_valid_signature if {
    input.signatures
    count(input.signatures) > 0
    some sig in input.signatures
    sig.keyId
    sig.signature
}

# Check 2: Model must have SBOM (both code and model)
has_valid_sbom if {
    input.sbom
    input.sbom.code
    input.sbom.model
    input.sbom.code.bomFormat == "CycloneDX"
    input.sbom.model.bomFormat == "CycloneDX"
}

# Check 3: Must have SLSA provenance attestation
has_slsa_provenance if {
    input.attestations
    some att in input.attestations
    att.predicateType == "https://slsa.dev/provenance/v0.2"
    att.predicate.buildType
    att.predicate.builder
}

# Check 4: Model accuracy must meet minimum threshold
meets_quality_threshold if {
    input.metadata
    input.metadata.accuracy >= 0.85
}

# Check 5: No critical vulnerabilities in dependencies
no_critical_vulnerabilities if {
    not has_critical_vulns
}

has_critical_vulns if {
    some component in input.sbom.code.components
    component.vulnerabilities
    some vuln in component.vulnerabilities
    vuln.severity == "CRITICAL"
}

# Violation messages for debugging
violations[msg] {
    not has_valid_signature
    msg := "Model artifact is not signed with cosign"
}

violations[msg] {
    not has_valid_sbom
    msg := "Model missing required SBOMs (code and model)"
}

violations[msg] {
    not has_slsa_provenance
    msg := "Model missing SLSA provenance attestation"
}

violations[msg] {
    not meets_quality_threshold
    threshold := 0.85
    accuracy := input.metadata.accuracy
    msg := sprintf("Model accuracy %.2f below threshold %.2f", [accuracy, threshold])
}

violations[msg] {
    has_critical_vulns
    msg := "Model dependencies contain critical vulnerabilities"
}

# Additional policy: Require specific builder
trusted_builder if {
    input.attestations[_].predicate.builder.id in {
        "github-actions",
        "gitlab-ci",
        "local-builder"  # For testing
    }
}

violations[msg] {
    not trusted_builder
    builder := input.attestations[_].predicate.builder.id
    msg := sprintf("Untrusted builder: %s", [builder])
}
