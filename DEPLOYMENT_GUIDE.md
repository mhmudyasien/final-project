# Infrastructure Improvements - Deployment Guide

## Overview

This document provides guidance on deploying the infrastructure improvements that have been implemented, including Kyverno admission controller, security hardening, network policies, and enhanced deployment scripts.

---

## What's New

### ✅ Implemented Improvements

1. **Kyverno Admission Controller**
   - Image signature verification for ECR images
   - Resource limits enforcement
   - Non-root container enforcement
   - Security policy automation

2. **Kubernetes Security Hardening**
   - Resource requests and limits on all pods
   - Pod security contexts (runAsNonRoot, drop capabilities)
   - Read-only root filesystem for frontend
   - imagePullPolicy: Always

3. **Network Policies**
   - Comprehensive ingress/egress rules for all environments
   - Backend: restricted to frontend, RDS, Redis, Vault, DNS
   - Frontend: restricted to backend and DNS
   - Applied to dev, staging, and prod

4. **Enhanced Bash Scripts**
   - Error handling and validation
   - Health checks and rollback capability
   - Parameterized configuration
   - Colored output and logging

---

## Deployment Steps

### Step 1: Install Kyverno (One-time setup)

```bash
# Install Kyverno and policies
./install-kyverno.sh
```

**What this does:**
- Installs Kyverno using Helm with HA configuration
- Applies policies in **Audit mode** (non-blocking)
- Creates ClusterPolicies for image verification and security

**Verify installation:**
```bash
kubectl get pods -n kyverno
kubectl get clusterpolicy
```

### Step 2: Review Policy Reports (Audit Mode)

```bash
# Check policy reports for violations
kubectl get policyreport -A

# View detailed report
kubectl describe policyreport <report-name> -n <namespace>
```

**Expected violations:**
- Existing deployments may not meet new security requirements
- This is normal - we'll fix them in the next step

### Step 3: Deploy Updated Manifests

The Kubernetes manifests have been updated with security improvements. Deploy them:

```bash
# Deploy to dev environment
./deploy.sh dev latest

# Deploy to staging
./deploy.sh staging latest

# Deploy to prod
./deploy.sh prod latest
```

**What the enhanced deploy.sh does:**
- Validates kubectl connectivity and AWS credentials
- Creates namespace if needed
- Applies all manifests with variable substitution
- Waits for deployments to be ready (5min timeout)
- Performs health checks on all pods
- Shows deployment status
- **Automatically rolls back on failure**

### Step 4: Verify Deployments

```bash
# Check pod status
kubectl get pods -n dev
kubectl get pods -n staging
kubectl get pods -n prod

# Verify resource limits are applied
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Limits\|Requests"

# Verify security context
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.securityContext}'
```

### Step 5: Enable Kyverno Enforce Mode

Once all deployments are compliant, switch Kyverno to enforce mode:

```bash
# Edit the image verification policy
kubectl edit clusterpolicy verify-ecr-signed-images

# Change this line:
#   validationFailureAction: Audit
# To:
#   validationFailureAction: Enforce

# Save and exit
```

**Test enforcement:**
```bash
# Try to deploy an unsigned image (should be blocked)
kubectl run test --image=nginx:latest -n dev
# Expected: Error from server: admission webhook denied the request
```

---

## Configuration

### Environment Variables

#### deploy.sh
```bash
# Optional: Disable automatic rollback on failure
export ROLLBACK_ON_FAILURE=false

# Deploy with custom timeout (default: 300s)
TIMEOUT=600 ./deploy.sh prod latest
```

#### get-config-values.sh
```bash
# Custom SSH key path
export SSH_KEY_PATH=/path/to/your/key.pem

# Custom EC2 user
export EC2_USER=ubuntu

# Custom Terraform directory
export TERRAFORM_DIR=./infrastructure/terraform

# Run the script
./get-config-values.sh
```

#### build-and-push.sh
```bash
# Custom AWS region
export AWS_REGION=us-west-2

# Build and push
./build-and-push.sh v1.2.3
```

---

## Security Improvements Summary

### Pod Security

| Feature | Before | After |
|---------|--------|-------|
| Resource Limits | ❌ None | ✅ CPU/Memory limits |
| Run as Root | ⚠️ Yes | ✅ No (UID 1000/101) |
| Privilege Escalation | ⚠️ Allowed | ✅ Blocked |
| Capabilities | ⚠️ All | ✅ Dropped ALL |
| Root Filesystem | ⚠️ Writable | ✅ Read-only (frontend) |
| Image Pull Policy | ⚠️ IfNotPresent | ✅ Always |

### Network Security

| Feature | Before | After |
|---------|--------|-------|
| Network Policies | ⚠️ Prod only | ✅ All environments |
| Egress Rules | ❌ None | ✅ Restricted |
| Frontend Policy | ❌ None | ✅ Implemented |
| DNS Access | ⚠️ Implicit | ✅ Explicit |

### Image Security

| Feature | Before | After |
|---------|--------|-------|
| Signature Verification | ❌ None | ✅ Cosign verification |
| Policy Enforcement | ❌ None | ✅ Kyverno policies |
| Unsigned Images | ⚠️ Allowed | ✅ Blocked (enforce mode) |

---

## Troubleshooting

### Kyverno Installation Issues

**Problem:** Kyverno pods not starting
```bash
# Check events
kubectl get events -n kyverno --sort-by='.lastTimestamp'

# Check pod logs
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno
```

**Solution:** Ensure sufficient cluster resources (Kyverno needs ~256Mi memory per pod)

### Deployment Failures

**Problem:** Pods fail to start with "runAsNonRoot" error
```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>
```

**Solution:** Ensure your Docker images don't require root. Update Dockerfile to use non-root user:
```dockerfile
# Backend (Python)
USER 1000:1000

# Frontend (Nginx)
USER 101:101
```

**Problem:** Frontend pods crash with "permission denied" errors
```bash
kubectl logs <frontend-pod> -n <namespace>
```

**Solution:** The frontend uses read-only filesystem with emptyDir volumes for nginx cache. Ensure nginx is configured to use these paths.

### Network Policy Issues

**Problem:** Backend can't connect to RDS/Redis
```bash
# Check network policy
kubectl describe networkpolicy backend-policy -n <namespace>

# Test connectivity from pod
kubectl exec -it <backend-pod> -n <namespace> -- nc -zv <rds-endpoint> 5432
```

**Solution:** Verify the CIDR blocks in network policies match your VPC subnets (10.0.20.0/24, 10.0.21.0/24)

### Image Verification Issues

**Problem:** Kyverno blocks signed images
```bash
# Check policy report
kubectl describe clusterpolicy verify-ecr-signed-images
```

**Solution:** 
1. Verify images are actually signed: `cosign verify <image>`
2. Check if using keyless or key-based signing
3. Ensure the policy matches your signing method (edit `k8s/kyverno/policies/verify-images.yaml`)

---

## Rollback Procedures

### Rollback Kubernetes Deployment

```bash
# Automatic rollback (handled by deploy.sh on failure)
# Manual rollback:
kubectl rollout undo deployment/backend -n <namespace>
kubectl rollout undo deployment/frontend -n <namespace>

# Rollback to specific revision
kubectl rollout history deployment/backend -n <namespace>
kubectl rollout undo deployment/backend --to-revision=2 -n <namespace>
```

### Disable Kyverno Policies

```bash
# Switch to audit mode
kubectl patch clusterpolicy verify-ecr-signed-images --type='json' \
  -p='[{"op": "replace", "path": "/spec/validationFailureAction", "value":"Audit"}]'

# Or delete the policy entirely
kubectl delete clusterpolicy verify-ecr-signed-images
```

### Uninstall Kyverno

```bash
helm uninstall kyverno -n kyverno
kubectl delete namespace kyverno
```

---

## Next Steps

### Recommended (Not Yet Implemented)

1. **Enable Vault TLS**
   - Requires ACM certificate
   - Update Terraform and Ansible configurations
   - See `implementation_plan.md` Phase 5

2. **Store Vault Keys in Secrets Manager**
   - Update Ansible to write init keys to AWS Secrets Manager
   - Remove local file storage

3. **Pin Images by Digest**
   - Update deployment workflow to use image digests
   - Example: `image@sha256:abc123...` instead of `image:tag`

4. **Multi-AZ RDS**
   - Enable when moving beyond Free Tier
   - Update `terraform/modules/rds/main.tf`

---

## Monitoring and Alerts

### Kyverno Metrics

```bash
# Port-forward to Kyverno metrics
kubectl port-forward -n kyverno svc/kyverno-svc-metrics 8000:8000

# Access metrics
curl http://localhost:8000/metrics
```

### Policy Violation Alerts

Set up alerts for policy violations:
```bash
# Get policy violation count
kubectl get policyreport -A -o json | \
  jq '.items[].results[] | select(.result=="fail") | .policy' | \
  sort | uniq -c
```

---

## Additional Resources

- [Kyverno Documentation](https://kyverno.io/docs/)
- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)

---

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review policy reports: `kubectl get policyreport -A`
3. Check deployment logs: `kubectl logs -n <namespace> <pod-name>`
4. Review the implementation plan: `implementation_plan.md`
