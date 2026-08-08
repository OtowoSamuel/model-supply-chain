# Terraform Infrastructure

This directory contains the Terraform configuration for deploying the ML Model Supply Chain infrastructure on AWS EKS.

---

## 🔧 Fixes Applied

Based on deployment issues encountered, the following fixes have been implemented:

### 1. EKS Access Configuration
**Problem**: kubectl authentication failed after cluster creation  
**Fix**: Added `authentication_mode = "API_AND_CONFIG_MAP"` and proper access entries

```hcl
authentication_mode = "API_AND_CONFIG_MAP"
enable_cluster_creator_admin_permissions = true

access_entries = {
  cluster_creator = {
    principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
    policy_associations = {
      admin = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = {
          type = "cluster"
        }
      }
    }
  }
}
```

### 2. Node Group IAM Role Name Length
**Problem**: Error - IAM role name prefix too long (>38 characters)  
**Fix**: Shortened role names and added `use_name_prefix` control

```hcl
iam_role_name = "eks-system-${var.environment}"  # Shortened from full cluster name
iam_role_use_name_prefix = false  # Prevents auto-prefixing
```

### 3. EKS Addon Conflict Resolution
**Problem**: Addons failed to install due to existing resources  
**Fix**: Added conflict resolution strategies

```hcl
cluster_addons = {
  coredns = {
    most_recent = true
    resolve_conflicts_on_create = "OVERWRITE"
    resolve_conflicts_on_update = "OVERWRITE"
  }
  # ... other addons
}
```

### 4. Node Taints Configuration
**Problem**: Invalid taint format for EKS managed node groups  
**Fix**: Changed from array to map format

```hcl
# Before (incorrect):
node_taints = [
  {
    key    = "workload"
    value  = "ml-model"
    effect = "NO_SCHEDULE"
  }
]

# After (correct):
taints = {
  ml_only = {
    key    = "workload"
    value  = "ml-model"
    effect = "NoSchedule"  # Note: NoSchedule not NO_SCHEDULE
  }
}
```

### 5. Cluster Logging
**Problem**: No control plane logs for troubleshooting  
**Fix**: Added explicit logging configuration

```hcl
cluster_enabled_log_types = ["api", "audit", "authenticator"]
```

### 6. Kubernetes Provider Dependencies
**Problem**: Provider tried to configure before cluster was ready  
**Fix**: Proper depends_on in Kubernetes resources

```hcl
resource "kubernetes_namespace" "kyverno" {
  # ...
  depends_on = [module.eks]
}
```

---

## 📁 Directory Structure

```
terraform/
├── README.md                    # This file
├── main.tf                      # Main infrastructure definition
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
├── locals.tf                    # Local values
├── bootstrap/                   # State backend setup
│   ├── main.tf                  # S3 + DynamoDB for state
│   └── outputs.tf
└── .terraform/                  # Terraform cache (gitignored)
```

---

## 🚀 Usage

### Prerequisites

1. **AWS CLI** configured with credentials
   ```bash
   aws configure
   aws sts get-caller-identity
   ```

2. **Terraform** installed (v1.5+)
   ```bash
   terraform version
   ```

3. **kubectl** installed
   ```bash
   kubectl version --client
   ```

### Quick Start

#### Option 1: Use the Apply Script (Recommended)
```bash
cd /Users/admin/Documents/Documents/Projects-2026/model-supply-chain
./scripts/terraform-apply-all.sh staging
```

#### Option 2: Manual Deployment

**Step 1: Create State Backend**
```bash
cd bootstrap
terraform init
terraform apply -auto-approve
```

**Step 2: Deploy Infrastructure**
```bash
cd ..
terraform init
terraform plan -var=environment=staging
terraform apply -var=environment=staging
```

**Step 3: Configure kubectl**
```bash
aws eks update-kubeconfig --region us-east-1 --name model-supply-chain-staging
kubectl get nodes
```

---

## 🗑️ Destruction

### Option 1: Use the Destroy Script (Recommended)
```bash
cd /Users/admin/Documents/Documents/Projects-2026/model-supply-chain
./scripts/terraform-destroy-all.sh
```

This script will:
1. Clean up Kubernetes resources first
2. Destroy main infrastructure
3. Check for orphaned resources
4. Optionally destroy state backend
5. Clean up local files

### Option 2: Manual Destruction

```bash
# Destroy main infrastructure
cd terraform
terraform destroy -var=environment=staging -auto-approve

# Optionally destroy state backend
cd bootstrap
terraform destroy -auto-approve
```

---

## 📊 State Management

### Remote State (S3 Backend)

State is stored remotely in S3 with DynamoDB locking:

```hcl
backend "s3" {
  bucket       = "tf-state-model-supply-chain-ACCOUNT_ID"
  key          = "eks/terraform.tfstate"
  region       = "us-east-1"
  encrypt      = true
  use_lockfile = true
}
```

### State Operations

```bash
# View current state
terraform show

# List resources
terraform state list

# View specific resource
terraform state show module.eks.aws_eks_cluster.this[0]

# Refresh state from AWS
terraform refresh -var=environment=staging

# Move resource in state
terraform state mv 'old.address' 'new.address'

# Import existing resource
terraform import 'module.eks.aws_eks_cluster.this[0]' cluster-name
```

---

## 🔍 Troubleshooting

### Issue: "Resource already exists"

**Cause**: Terraform state out of sync with AWS  
**Solution**: Import the existing resource

```bash
# Example: Import EKS cluster
terraform import 'module.eks.aws_eks_cluster.this[0]' model-supply-chain-staging

# Example: Import node group
terraform import 'module.eks.module.eks_managed_node_group["system"].aws_eks_node_group.this[0]' \
  model-supply-chain-staging:model-supply-chain-staging-system-xxxxx
```

### Issue: "State lock timeout"

**Cause**: Previous terraform operation didn't release lock  
**Solution**: Force unlock

```bash
# Get lock ID from error message, then:
terraform force-unlock LOCK_ID
```

### Issue: "Backend initialization required"

**Cause**: Backend not configured or changed  
**Solution**: Reinitialize

```bash
terraform init -reconfigure
```

### Issue: kubectl access fails after apply

**Cause**: EKS access entry not properly configured  
**Solution**: Run fix script

```bash
cd ..
./scripts/fix-kubectl-access.sh
```

---

## 🔒 Security Considerations

### Secrets in State

⚠️ **Warning**: Terraform state may contain sensitive data

- State file is encrypted at rest (S3 server-side encryption)
- Use DynamoDB locking to prevent concurrent modifications
- Never commit `.tfstate` files to git
- Use IAM policies to restrict state bucket access

### Least Privilege

All IAM roles follow least privilege:
- EKS cluster role: Only necessary permissions
- Node group roles: ECR read, EC2 describe
- GitHub Actions role: ECR push, EKS describe

### Network Isolation

- Nodes run in private subnets
- NAT Gateway for outbound internet
- Security groups restrict traffic
- VPC endpoints for AWS services (optional)

---

## 📈 Scaling

### Horizontal Scaling (More Nodes)

```bash
# Update variables
terraform apply -var="ml_node_desired=5" -var="ml_node_max=10"
```

### Vertical Scaling (Larger Instances)

```bash
# Update variables
terraform apply -var="ml_node_instance_type=t3.2xlarge"
```

### Multi-Environment

```bash
# Production deployment
terraform apply -var=environment=production \
  -var="system_node_instance_type=t3.large" \
  -var="ml_node_desired=3"
```

---

## 💰 Cost Optimization

### Current Costs (Staging)

| Resource | Monthly Cost |
|----------|-------------|
| EKS Control Plane | $73 |
| 2x t3.medium | $60 |
| 2x t3.xlarge | $30 |
| NAT Gateway | $33 |
| EBS + ECR | $10 |
| **Total** | **~$206** |

### Cost Reduction Strategies

1. **Use Spot Instances** (60-70% savings):
   ```hcl
   capacity_type = "SPOT"
   ```

2. **Single NAT Gateway** (staging):
   ```hcl
   single_nat_gateway = true  # Already enabled
   ```

3. **Auto-scaling**:
   - Scale down during off-hours
   - Use Horizontal Pod Autoscaler (HPA)
   - Cluster Autoscaler for nodes

4. **Reserved Instances** (30-40% savings):
   - Purchase RIs for production

---

## 🧪 Testing

### Validate Configuration

```bash
terraform validate
terraform fmt -check
```

### Plan Changes

```bash
terraform plan -var=environment=staging -out=tfplan
```

### Apply with Target

```bash
# Apply specific resource
terraform apply -target=module.eks -var=environment=staging

# Apply specific node group
terraform apply -target='module.eks.module.eks_managed_node_group["system"]' \
  -var=environment=staging
```

---

## 📚 Additional Resources

- **Terraform AWS EKS Module**: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws
- **EKS Best Practices**: https://aws.github.io/aws-eks-best-practices/
- **Terraform State**: https://www.terraform.io/docs/language/state/

---

## 🐛 Known Issues

### Issue #1: Cluster Recreation on Apply

**Status**: Fixed  
**Cause**: `bootstrap_self_managed_addons` parameter mismatch  
**Fix**: Removed from configuration, cluster now stable

### Issue #2: kubectl Authentication

**Status**: Fixed  
**Cause**: Access entries not configured  
**Fix**: Added explicit access_entries configuration

### Issue #3: IAM Role Name Too Long

**Status**: Fixed  
**Cause**: Full cluster name used as prefix  
**Fix**: Shortened to `eks-{nodegroup}-{env}`

---

## ✅ Verification Checklist

After deployment, verify:

- [ ] `terraform plan` shows no changes
- [ ] EKS cluster status is ACTIVE
- [ ] All node groups are ACTIVE
- [ ] kubectl can access cluster
- [ ] Nodes are in Ready state
- [ ] ECR repository exists
- [ ] IAM roles have correct permissions
- [ ] S3 state bucket has versioning enabled
- [ ] DynamoDB lock table exists

---

*Last Updated: July 14, 2026*  
*Terraform Version: 1.5+*  
*AWS Provider Version: ~> 5.50*
