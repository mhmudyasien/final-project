#!/bin/bash
set -euo pipefail

# Enhanced deployment script with error handling, validation, and health checks

# Configuration
ENVIRONMENT="${1:-dev}" # dev, staging, or prod
IMAGE_TAG="${2:-latest}"
TIMEOUT=300  # 5 minutes timeout for deployment
HEALTH_CHECK_RETRIES=30
HEALTH_CHECK_INTERVAL=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cleanup function for rollback
cleanup() {
    if [ $? -ne 0 ]; then
        log_error "Deployment failed! Check logs above for details."
        if [ "${ROLLBACK_ON_FAILURE:-true}" = "true" ]; then
            log_warn "Initiating rollback..."
            rollback_deployment
        fi
    fi
}

trap cleanup EXIT

# Rollback function
rollback_deployment() {
    log_warn "Rolling back deployments in namespace: $ENVIRONMENT"
    
    # Rollback backend
    if ./kubectl rollout undo deployment/backend -n "$ENVIRONMENT" 2>/dev/null; then
        log_info "Backend rolled back successfully"
    else
        log_warn "Backend rollback failed or no previous revision available"
    fi
    
    # Rollback frontend
    if ./kubectl rollout undo deployment/frontend -n "$ENVIRONMENT" 2>/dev/null; then
        log_info "Frontend rolled back successfully"
    else
        log_warn "Frontend rollback failed or no previous revision available"
    fi
}

# Validation functions
validate_environment() {
    case "$ENVIRONMENT" in
        dev|staging|prod)
            log_info "Deploying to environment: $ENVIRONMENT"
            ;;
        *)
            log_error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod."
            exit 1
            ;;
    esac
}

validate_kubectl() {
    log_info "Validating kubectl connectivity..."
    
    if [ ! -f "./kubectl" ]; then
        log_error "kubectl binary not found in current directory"
        exit 1
    fi
    
    if ! ./kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    log_info "kubectl connectivity verified"
}

validate_aws_credentials() {
    log_info "Validating AWS credentials..."
    
    if ! command -v aws >/dev/null 2>&1; then
        log_error "AWS CLI not found. Please install it."
        exit 1
    fi
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    log_info "AWS credentials validated"
}

# Fetch AWS Details
fetch_aws_details() {
    log_info "Fetching AWS details..."
    
    export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    export AWS_REGION=$(aws configure get region)
    export IMAGE_TAG=$IMAGE_TAG
    
    if [ -z "$AWS_REGION" ]; then
        export AWS_REGION="us-east-2" # Fallback
        log_warn "AWS region not configured, using fallback: $AWS_REGION"
    fi
    
    log_info "AWS Account: $AWS_ACCOUNT_ID"
    log_info "AWS Region: $AWS_REGION"
    log_info "Image Tag: $IMAGE_TAG"
}

# Create namespace if not exists
create_namespace() {
    log_info "Ensuring namespace '$ENVIRONMENT' exists..."
    ./kubectl create namespace "$ENVIRONMENT" --dry-run=client -o yaml | ./kubectl apply -f -
}

# Apply manifests
apply_manifests() {
    log_info "Applying Kubernetes manifests for $ENVIRONMENT..."
    
    local manifest_dir="k8s/$ENVIRONMENT"
    
    if [ ! -d "$manifest_dir" ]; then
        log_error "Manifest directory not found: $manifest_dir"
        exit 1
    fi
    
    local manifest_count=0
    for file in "$manifest_dir"/*.yaml; do
        if [ -f "$file" ]; then
            log_info "Processing $(basename "$file")..."
            if envsubst < "$file" | ./kubectl apply -f -; then
                ((manifest_count++))
            else
                log_error "Failed to apply $file"
                exit 1
            fi
        fi
    done
    
    if [ $manifest_count -eq 0 ]; then
        log_error "No manifests found in $manifest_dir"
        exit 1
    fi
    
    log_info "Applied $manifest_count manifests successfully"
}

# Wait for deployments to be ready
wait_for_deployments() {
    log_info "Waiting for deployments to be ready (timeout: ${TIMEOUT}s)..."
    
    # Wait for backend deployment
    if ./kubectl get deployment backend -n "$ENVIRONMENT" >/dev/null 2>&1; then
        log_info "Waiting for backend deployment..."
        if ! ./kubectl rollout status deployment/backend -n "$ENVIRONMENT" --timeout="${TIMEOUT}s"; then
            log_error "Backend deployment failed to become ready"
            return 1
        fi
        log_info "Backend deployment ready"
    fi
    
    # Wait for frontend deployment
    if ./kubectl get deployment frontend -n "$ENVIRONMENT" >/dev/null 2>&1; then
        log_info "Waiting for frontend deployment..."
        if ! ./kubectl rollout status deployment/frontend -n "$ENVIRONMENT" --timeout="${TIMEOUT}s"; then
            log_error "Frontend deployment failed to become ready"
            return 1
        fi
        log_info "Frontend deployment ready"
    fi
    
    return 0
}

# Health check function
perform_health_checks() {
    log_info "Performing health checks..."
    
    local retry=0
    local backend_healthy=false
    local frontend_healthy=false
    
    # Check backend pods
    while [ $retry -lt $HEALTH_CHECK_RETRIES ]; do
        local backend_ready=$(./kubectl get pods -n "$ENVIRONMENT" -l app=backend -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -o "True" | wc -l)
        local backend_total=$(./kubectl get pods -n "$ENVIRONMENT" -l app=backend --no-headers 2>/dev/null | wc -l)
        
        if [ "$backend_ready" -gt 0 ] && [ "$backend_ready" -eq "$backend_total" ]; then
            backend_healthy=true
            log_info "Backend health check passed ($backend_ready/$backend_total pods ready)"
            break
        fi
        
        log_warn "Backend health check: $backend_ready/$backend_total pods ready (retry $((retry+1))/$HEALTH_CHECK_RETRIES)"
        sleep $HEALTH_CHECK_INTERVAL
        ((retry++))
    done
    
    # Check frontend pods
    retry=0
    while [ $retry -lt $HEALTH_CHECK_RETRIES ]; do
        local frontend_ready=$(./kubectl get pods -n "$ENVIRONMENT" -l app=frontend -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -o "True" | wc -l)
        local frontend_total=$(./kubectl get pods -n "$ENVIRONMENT" -l app=frontend --no-headers 2>/dev/null | wc -l)
        
        if [ "$frontend_ready" -gt 0 ] && [ "$frontend_ready" -eq "$frontend_total" ]; then
            frontend_healthy=true
            log_info "Frontend health check passed ($frontend_ready/$frontend_total pods ready)"
            break
        fi
        
        log_warn "Frontend health check: $frontend_ready/$frontend_total pods ready (retry $((retry+1))/$HEALTH_CHECK_RETRIES)"
        sleep $HEALTH_CHECK_INTERVAL
        ((retry++))
    done
    
    if [ "$backend_healthy" = false ] || [ "$frontend_healthy" = false ]; then
        log_error "Health checks failed"
        return 1
    fi
    
    log_info "All health checks passed"
    return 0
}

# Display deployment status
show_deployment_status() {
    log_info "Deployment Status:"
    echo ""
    echo "=== Pods ==="
    ./kubectl get pods -n "$ENVIRONMENT" -o wide
    echo ""
    echo "=== Services ==="
    ./kubectl get services -n "$ENVIRONMENT"
    echo ""
    echo "=== Deployments ==="
    ./kubectl get deployments -n "$ENVIRONMENT"
    echo ""
}

# Main execution
main() {
    log_info "=========================================="
    log_info "Kubernetes Deployment Script"
    log_info "=========================================="
    log_info "Environment: $ENVIRONMENT"
    log_info "Image Tag: $IMAGE_TAG"
    log_info "=========================================="
    echo ""
    
    # Validation
    validate_environment
    validate_kubectl
    validate_aws_credentials
    
    # Fetch AWS details
    fetch_aws_details
    
    # Create namespace
    create_namespace
    
    # Apply manifests
    apply_manifests
    
    # Wait for deployments
    if ! wait_for_deployments; then
        log_error "Deployment failed during rollout"
        exit 1
    fi
    
    # Perform health checks
    if ! perform_health_checks; then
        log_error "Deployment failed health checks"
        exit 1
    fi
    
    # Show status
    show_deployment_status
    
    log_info "=========================================="
    log_info "Deployment completed successfully!"
    log_info "=========================================="
}

# Run main function
main
