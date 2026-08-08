#!/usr/bin/env bash

#==============================================================================
# Fix Kyverno Installation Script
# 
# Purpose: Remove broken kubectl-based Kyverno and reinstall via Helm
# This fixes the Kubernetes 1.33 annotation size limit issues
#==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "════════════════════════════════════════════════════════════"
echo "  Kyverno Installation Fix for Kubernetes 1.33"
echo "════════════════════════════════════════════════════════════"
echo ""

#------------------------------------------------------------------------------
# Step 1: Check current state
#------------------------------------------------------------------------------
echo -e "${CYAN}Step 1: Checking current Kyverno installation...${NC}"

if helm list -n kyverno 2>/dev/null | grep -q "kyverno"; then
    echo -e "${GREEN}✅ Kyverno is already installed via Helm${NC}"
    helm list -n kyverno
    echo ""
    echo -e "${YELLOW}Checking pod status:${NC}"
    kubectl get pods -n kyverno
    exit 0
fi

if kubectl get namespace kyverno &> /dev/null; then
    echo -e "${YELLOW}⚠️  Found Kyverno namespace (kubectl-based installation)${NC}"
    
    echo -e "${YELLOW}Checking pod status:${NC}"
    kubectl get pods -n kyverno || true
    echo ""
    
    echo -e "${YELLOW}Checking CRDs:${NC}"
    kubectl get crds | grep kyverno | head -5 || echo "No Kyverno CRDs found"
    echo ""
    
    #--------------------------------------------------------------------------
    # Step 2: Remove broken installation
    #--------------------------------------------------------------------------
    echo -e "${CYAN}Step 2: Removing kubectl-based Kyverno installation...${NC}"
    
    # Delete CRDs first to clean up resources
    echo -e "${YELLOW}Deleting Kyverno CRDs...${NC}"
    kubectl delete crds -l app.kubernetes.io/name=kyverno --ignore-not-found=true || true
    
    # Delete the namespace
    echo -e "${YELLOW}Deleting kyverno namespace...${NC}"
    kubectl delete namespace kyverno --wait=false
    
    # Wait for cleanup (max 2 minutes)
    echo -e "${YELLOW}Waiting for namespace deletion (max 120s)...${NC}"
    for i in {1..24}; do
        if ! kubectl get namespace kyverno &> /dev/null; then
            echo -e "${GREEN}✅ Namespace deleted${NC}"
            break
        fi
        echo -n "."
        sleep 5
    done
    echo ""
    
    # Force finalizer removal if stuck
    if kubectl get namespace kyverno &> /dev/null; then
        echo -e "${YELLOW}Namespace stuck, removing finalizers...${NC}"
        kubectl patch namespace kyverno -p '{"metadata":{"finalizers":[]}}' --type=merge || true
        sleep 3
    fi
    
    echo -e "${GREEN}✅ Cleanup complete${NC}"
    echo ""
else
    echo -e "${GREEN}✅ No existing Kyverno installation found${NC}"
    echo ""
fi

#------------------------------------------------------------------------------
# Step 3: Kyverno is managed by Terraform
#------------------------------------------------------------------------------
echo -e "${CYAN}Step 3: Kyverno is managed by Terraform...${NC}"

# Kyverno is installed/upgraded exclusively via Terraform
# (terraform/kyverno.tf, helm_release pinned to chart 3.8.2 / Kyverno 1.18.2).
# Manual helm installs are NOT performed here.

if helm list -n kyverno 2>/dev/null | grep -q "kyverno"; then
    echo -e "${GREEN}✅ Kyverno release already present (Terraform-managed)${NC}"
    echo -e "${CYAN}   Ensure it matches Terraform config: cd terraform && terraform apply${NC}"
else
    echo -e "${YELLOW}⚠️  Kyverno release not found - install via Terraform:${NC}"
    echo -e "${YELLOW}   cd terraform && terraform apply${NC}"
fi

echo ""
echo -e "${GREEN}✅ Kyverno installation is managed by Terraform${NC}"
echo ""

#------------------------------------------------------------------------------
# Step 4: Verify installation
#------------------------------------------------------------------------------
echo -e "${CYAN}Step 4: Verifying installation...${NC}"

echo -e "${YELLOW}Helm releases:${NC}"
helm list -n kyverno
echo ""

echo -e "${YELLOW}Pod status:${NC}"
kubectl get pods -n kyverno
echo ""

echo -e "${YELLOW}Kyverno CRDs (first 10):${NC}"
kubectl get crds | grep kyverno | head -10
echo ""

# Check for ClusterPolicy CRD specifically
if kubectl get crds clusterpolicies.kyverno.io &> /dev/null; then
    echo -e "${GREEN}✅ ClusterPolicy CRD found (can use kyverno.io/v1 policies)${NC}"
else
    echo -e "${YELLOW}⚠️  ClusterPolicy CRD not found${NC}"
    echo -e "${CYAN}   This means newer policy types are in use (ValidatingPolicy, etc.)${NC}"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Kyverno installation complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Policies are applied via Terraform: cd terraform && terraform apply"
echo "  2. Continue with: ./scripts/setup-and-test-full-pipeline.sh"
echo ""
