#!/bin/bash
set -e

echo "======================================"
echo "Installing Kyverno Admission Controller"
echo "======================================"

# Check prerequisites
echo "Checking prerequisites..."
command -v helm >/dev/null 2>&1 || { echo "Error: helm is required but not installed. Aborting." >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl is required but not installed. Aborting." >&2; exit 1; }

# Verify kubectl connectivity
echo "Verifying kubectl connectivity..."
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "Error: Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

# Add Kyverno Helm repository
echo "Adding Kyverno Helm repository..."
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

# Install Kyverno
echo "Installing Kyverno..."
helm upgrade --install kyverno kyverno/kyverno \
    --namespace kyverno \
    --create-namespace \
    --values k8s/kyverno/kyverno-values.yaml \
    --wait \
    --timeout 5m

# Wait for Kyverno to be ready
echo "Waiting for Kyverno pods to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=kyverno \
    -n kyverno \
    --timeout=300s

# Verify installation
echo ""
echo "Verifying Kyverno installation..."
kubectl get pods -n kyverno
echo ""

# Apply policies in audit mode first
echo "======================================"
echo "Applying Kyverno Policies (Audit Mode)"
echo "======================================"

echo "Applying image verification policy..."
kubectl apply -f k8s/kyverno/policies/verify-images.yaml

echo "Applying resource limits policy..."
kubectl apply -f k8s/kyverno/policies/require-resources.yaml

echo "Applying non-root containers policy..."
kubectl apply -f k8s/kyverno/policies/require-non-root.yaml

# Wait for policies to be ready
echo ""
echo "Waiting for policies to be ready..."
sleep 5

# Show policy status
echo ""
echo "======================================"
echo "Kyverno Policies Status"
echo "======================================"
kubectl get clusterpolicy

echo ""
echo "======================================"
echo "Installation Complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Review policy reports: kubectl get policyreport -A"
echo "2. Check for violations: kubectl describe policyreport <report-name> -n <namespace>"
echo "3. Fix any violations in your deployments"
echo "4. Switch policies to Enforce mode by editing the policies:"
echo "   - Edit k8s/kyverno/policies/verify-images.yaml"
echo "   - Change 'validationFailureAction: Audit' to 'validationFailureAction: Enforce'"
echo "   - Apply: kubectl apply -f k8s/kyverno/policies/verify-images.yaml"
echo ""
echo "To uninstall: helm uninstall kyverno -n kyverno"
echo ""
