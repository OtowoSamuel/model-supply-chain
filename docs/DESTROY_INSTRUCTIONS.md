# Infrastructure Destruction Instructions

## ⚡ Quick Destroy (Stops Costs Immediately)

Run this command in your terminal:

```bash
cd /Users/admin/Documents/Documents/Projects-2026/model-supply-chain
./DESTROY_NOW.sh
```

This will:
1. Delete node groups (stops ~$90/month EC2 costs)
2. Delete EKS cluster (stops ~$73/month)
3. Delete NAT Gateway (stops ~$33/month)
4. Release Elastic IPs

**Total cost reduction: ~$196/month stopped immediately**

---

## 🔧 Complete Cleanup (After Quick Destroy)

After running the quick destroy script above, wait 10-15 minutes for resources to delete, then run:

```bash
cd /Users/admin/Documents/Documents/Projects-2026/model-supply-chain/terraform

# Remove the state lock if needed
aws dynamodb delete-item \
  --table-name tf-state-lock-model-supply-chain \
  --key '{"LockID":{"S":"tf-state-model-supply-chain-050083686295/eks/terraform.tfstate"}}' \
  --region us-east-1

# Destroy remaining infrastructure
terraform destroy -var=environment=staging -auto-approve
```

This will clean up:
- VPC and subnets
- Security groups
- IAM roles and policies
- ECR repository (and container images)
- CloudWatch log groups

---

## 🗑️ Optional: Destroy State Backend

If you want to completely remove everything including the Terraform state:

```bash
cd /Users/admin/Documents/Documents/Projects-2026/model-supply-chain/terraform/bootstrap
terraform destroy -auto-approve
```

This will delete:
- S3 bucket (terraform state)
- DynamoDB table (state locking)

⚠️ **Warning**: After this, you won't be able to track what was deployed with Terraform.

---

## ✅ Verification

Check that everything is deleted:

```bash
# Check EKS cluster
aws eks describe-cluster --name model-supply-chain-staging --region us-east-1 2>&1 | grep -i "not found"

# Check EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=model-supply-chain-staging" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
  --region us-east-1

# Check NAT Gateways
aws ec2 describe-nat-gateways \
  --filter "Name=tag:Name,Values=*model-supply-chain*" \
  --region us-east-1 \
  --query 'NatGateways[*].[NatGatewayId,State]'

# Check VPC
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=*model-supply-chain*" \
  --region us-east-1

# Check ECR
aws ecr describe-repositories \
  --region us-east-1 | grep model-supply-chain
```

---

## 💰 Cost After Deletion

After complete deletion:
- **EKS cluster**: $0
- **EC2 nodes**: $0
- **NAT Gateway**: $0
- **ECR**: $0 (after images deleted)
- **S3 state**: ~$0.50/month (minimal)
- **DynamoDB**: ~$1/month (minimal)

**Total remaining cost: ~$1.50/month (if you keep state backend)**

---

## 🚨 Troubleshooting

### Issue: "ResourceInUseException" when deleting cluster

**Solution**: Node groups must be deleted first (script handles this)

### Issue: "DependencyViolation" when deleting NAT Gateway

**Solution**: Wait 2-3 minutes, NAT Gateway takes time to detach

### Issue: Terraform destroy hangs

**Solution**: Use the quick destroy script instead, then clean up with terraform

### Issue: State lock error

**Solution**: Run the DynamoDB delete-item command shown above

---

## 📞 Need Help?

If anything goes wrong:

1. Check AWS Console → EKS → Clusters
2. Check AWS Console → EC2 → Instances
3. Check AWS Console → VPC → NAT Gateways

Delete manually through console if needed.

---

**Estimated Total Deletion Time**: 15-20 minutes  
**Cost Reduction**: ~$216/month → $0
