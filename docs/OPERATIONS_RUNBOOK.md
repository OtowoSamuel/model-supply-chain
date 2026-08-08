# Operations Runbook

Quick reference for common operational tasks.

---

## Daily Operations

### Check Cluster Health

```bash
# Cluster status
kubectl get nodes
kubectl get pods -A

# Resource usage
kubectl top nodes
kubectl top pods -A
```

### Monitor Pipeline

```bash
# Recent runs
gh run list --workflow=model-pipeline.yml --limit 5

# Watch active run
gh run watch

# View logs
gh run view --log
```

### Check Model Deployments

```bash
# Deployment status
kubectl get deployment model-server
kubectl rollout status deployment/model-server

# Pod logs
kubectl logs -l app=model-server --tail=100 -f

# Service endpoint
kubectl get svc model-server
```

---

## Incident Response

### Pod Failures

```bash
# Find failing pods
kubectl get pods -A | grep -v Running

# Diagnose
kubectl describe pod <pod-name>
kubectl logs <pod-name> --previous

# Restart
kubectl delete pod <pod-name>  # Will auto-recreate
```

### Node Issues

```bash
# Check node conditions
kubectl describe node <node-name>

# Drain node for maintenance
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Uncordon after fix
kubectl uncordon <node-name>
```

### Pipeline Failures

```bash
# View failed run
gh run view <run-id> --log

# Re-run failed jobs
gh run rerun <run-id> --failed

# Re-run entire workflow
gh run rerun <run-id>
```

---

## Deployment Tasks

### Deploy New Model Version

```bash
# Option 1: Push code change (automatic)
git add src/train_model.py
git commit -m "Update model to v1.1.0"
git push origin main

# Option 2: Manual trigger
gh workflow run model-pipeline.yml

# Monitor
gh run watch
```

### Rollback Deployment

```bash
# Check history
kubectl rollout history deployment/model-server

# Rollback
kubectl rollout undo deployment/model-server

# Rollback to specific revision
kubectl rollout undo deployment/model-server --to-revision=2
```

### Scale Application

```bash
# Scale pods
kubectl scale deployment model-server --replicas=5

# Scale nodes (auto-scaling group)
aws eks update-nodegroup-config \
  --cluster-name model-supply-chain-staging \
  --nodegroup-name ml_model \
  --scaling-config minSize=2,maxSize=5,desiredSize=3
```

---

## Maintenance Tasks

### Update EKS Cluster

```bash
cd terraform
terraform plan -var=environment=staging
terraform apply -var=environment=staging

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name model-supply-chain-staging
```

### Rotate Cosign Keys

```bash
# Generate new key pair
cd keys
cosign generate-key-pair -f cosign-new.key

# Update GitHub secret
gh secret set COSIGN_PRIVATE_KEY < cosign-new.key

# Update public key in repo
mv cosign.pub cosign.pub.old
mv cosign-new.pub cosign.pub
git add keys/cosign.pub
git commit -m "Rotate Cosign public key"
git push

# Update Kyverno policy with new public key
kubectl edit clusterpolicy verify-model-signatures
```

### Clean Old Images

```bash
# List images
aws ecr describe-images \
  --repository-name model-supply-chain \
  --query 'sort_by(imageDetails,& imagePushedAt)[*].[imageTags[0],imagePushedAt]' \
  --output table

# Delete specific image
aws ecr batch-delete-image \
  --repository-name model-supply-chain \
  --image-ids imageTag=old-tag
```

### Backup Model Artifacts

```bash
# Archive current artifacts
tar -czf model-backup-$(date +%Y%m%d).tar.gz artifacts/

# Upload to S3
aws s3 cp model-backup-*.tar.gz s3://your-backup-bucket/models/
```

---

## Monitoring & Alerts

### View Logs

```bash
# Application logs
kubectl logs -l app=model-server --tail=100 -f

# All pods in namespace
kubectl logs -n default --all-containers=true --tail=50

# Specific container
kubectl logs <pod-name> -c <container-name>
```

### Check Metrics

```bash
# Resource usage
kubectl top pods -l app=model-server
kubectl top nodes

# Detailed metrics (if metrics-server installed)
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods
```

### CloudWatch Insights Queries

```sql
-- Error rate
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() by bin(5m)

-- Request latency
fields @timestamp, latency
| stats avg(latency), max(latency), p99(latency) by bin(5m)
```

---

## Security Tasks

### Verify Artifact Signatures

```bash
# Local verification
cd artifacts
cosign verify --key ../keys/cosign.pub model.pkl.bundle

# ECR image verification
cosign verify --key keys/cosign.pub \
  050083686295.dkr.ecr.us-east-1.amazonaws.com/model-supply-chain:latest
```

### Audit SBOM

```bash
# View SBOM
cat artifacts/sbom/model-sbom.json | jq .

# Check for vulnerabilities (if Grype installed)
grype sbom:artifacts/sbom/code-sbom.json
```

### Test Policy Enforcement

```bash
# Try deploying unsigned image (should fail)
kubectl run test-unsigned --image=python:3.9 --rm -it

# Check Kyverno policy reports
kubectl get policyreport -A
```

### Review Access Logs

```bash
# EKS audit logs (if enabled)
aws logs tail /aws/eks/model-supply-chain-staging/cluster --follow

# GitHub Actions logs
gh run list --limit 10
```

---

## Performance Tuning

### Optimize Resource Limits

```yaml
# Edit deployment
kubectl edit deployment model-server

# Update resources:
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "1Gi"
    cpu: "1000m"
```

### Enable Autoscaling

```bash
# Horizontal Pod Autoscaler
kubectl autoscale deployment model-server \
  --cpu-percent=70 \
  --min=2 \
  --max=10

# Check HPA
kubectl get hpa
```

### Node Autoscaling

Already configured in Terraform:
- System nodes: 2-4 instances
- ML nodes: 1-3 instances

Adjust in `terraform/main.tf` if needed.

---

## Cost Optimization

### Identify Cost Drivers

```bash
# Check node types and count
kubectl get nodes --show-labels

# Review running workloads
kubectl get pods -A -o wide

# ECR storage
aws ecr describe-repositories
```

### Reduce Costs

```bash
# Scale down non-prod during off-hours
kubectl scale deployment model-server --replicas=1

# Use spot instances (edit terraform/main.tf)
capacity_type = "SPOT"

# Delete idle resources
kubectl delete deployment <unused-deployment>
```

---

## Emergency Procedures

### Complete Cluster Outage

1. Check AWS status: https://status.aws.amazon.com
2. Verify EKS cluster status:
   ```bash
   aws eks describe-cluster --name model-supply-chain-staging
   ```
3. Check node health:
   ```bash
   kubectl get nodes
   aws ec2 describe-instances --filters "Name=tag:eks:cluster-name,Values=model-supply-chain-staging"
   ```
4. Recreate nodes if needed:
   ```bash
   terraform taint 'module.eks.module.eks_managed_node_group["system"]'
   terraform apply -var=environment=staging
   ```

### Data Loss Recovery

1. Restore from S3 backup:
   ```bash
   aws s3 cp s3://backup-bucket/models/model-backup-YYYYMMDD.tar.gz .
   tar -xzf model-backup-YYYYMMDD.tar.gz
   ```
2. Re-run pipeline from backup:
   ```bash
   git checkout <commit-hash>
   gh workflow run model-pipeline.yml
   ```

### Security Breach

1. Rotate all credentials immediately:
   ```bash
   # Rotate Cosign keys (see Maintenance Tasks)
   # Rotate AWS keys
   aws iam create-access-key --user-name github-actions
   gh secret set AWS_ACCESS_KEY_ID
   gh secret set AWS_SECRET_ACCESS_KEY
   ```
2. Review audit logs:
   ```bash
   aws cloudtrail lookup-events --lookup-attributes AttributeKey=Username,AttributeValue=github-actions
   ```
3. Redeploy with verified artifacts

---

## Useful Commands Reference

### kubectl Quick Commands

```bash
# Context management
kubectl config get-contexts
kubectl config use-context <context-name>

# Quick lookups
kubectl get all -A
kubectl get events --sort-by='.lastTimestamp'
kubectl api-resources

# Debugging
kubectl explain pod.spec.containers
kubectl diff -f deployment.yaml
kubectl apply --dry-run=client -f deployment.yaml

# Port forwarding
kubectl port-forward svc/model-server 8080:80
```

### AWS CLI Quick Commands

```bash
# EKS
aws eks list-clusters
aws eks describe-cluster --name <cluster-name>

# ECR
aws ecr get-login-password | docker login --username AWS --password-stdin <account>.dkr.ecr.<region>.amazonaws.com
aws ecr list-images --repository-name model-supply-chain

# IAM
aws sts get-caller-identity
aws iam get-role --role-name github-actions-model-supply-chain
```

### GitHub CLI Quick Commands

```bash
# Workflows
gh workflow list
gh workflow view model-pipeline.yml
gh workflow run model-pipeline.yml

# Runs
gh run list --workflow=model-pipeline.yml
gh run view <run-id>
gh run watch

# Secrets
gh secret list
gh secret set SECRET_NAME
```

---

## Contact & Escalation

**On-Call Engineer**: Check PagerDuty rotation  
**Slack Channel**: #ml-supply-chain-ops  
**Documentation**: https://github.com/your-org/model-supply-chain  
**Runbook Repository**: This file

---

*Last Updated: July 14, 2026*
