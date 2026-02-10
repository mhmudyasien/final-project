#!/bin/bash
set -euo pipefail

# Enhanced Docker build and push script with validation

# Configuration
AWS_REGION=${AWS_REGION:-"us-east-2"}
IMAGE_TAG=${1:-"latest"}
REPO_BACKEND="capstone-project-backend"
REPO_FRONTEND="capstone-project-frontend"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0;33m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validation
log_info "=========================================="
log_info "Docker Build and Push to ECR"
log_info "=========================================="

# Check Docker daemon
if ! docker info >/dev/null 2>&1; then
    log_error "Docker daemon is not running. Please start Docker."
    exit 1
fi

# Check AWS CLI
if ! command -v aws >/dev/null 2>&1; then
    log_error "AWS CLI not found. Please install it."
    exit 1
fi

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [ -z "$AWS_ACCOUNT_ID" ]; then
    log_error "Failed to get AWS account ID. Check your AWS credentials."
    exit 1
fi

log_info "AWS Region: $AWS_REGION"
log_info "AWS Account: $AWS_ACCOUNT_ID"
log_info "Image Tag: $IMAGE_TAG"
log_info "=========================================="

# Login to ECR
log_info "Logging in to ECR..."
if ! aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"; then
    log_error "Failed to login to ECR"
    exit 1
fi
log_info "ECR login successful"

# Function to ensure repo exists
ensure_repo() {
    REPO_NAME=$1
    log_info "Checking repository: $REPO_NAME"
    
    if ! aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
        log_warn "Repository $REPO_NAME does not exist. Creating..."
        if aws ecr create-repository --repository-name "$REPO_NAME" --region "$AWS_REGION" --image-scanning-configuration scanOnPush=true >/dev/null 2>&1; then
            log_info "Repository $REPO_NAME created successfully"
        else
            log_error "Failed to create repository $REPO_NAME"
            exit 1
        fi
    else
        log_info "Repository $REPO_NAME exists"
    fi
}

# Build and push function
build_and_push() {
    local SERVICE=$1
    local REPO=$2
    local CONTEXT=$3
    
    log_info "=========================================="
    log_info "Building $SERVICE..."
    log_info "=========================================="
    
    if [ ! -d "$CONTEXT" ]; then
        log_error "Context directory not found: $CONTEXT"
        exit 1
    fi
    
    if [ ! -f "$CONTEXT/Dockerfile" ]; then
        log_error "Dockerfile not found in: $CONTEXT"
        exit 1
    fi
    
    # Build with build cache
    if ! docker build \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        -t "$REPO:$IMAGE_TAG" \
        "$CONTEXT"; then
        log_error "Failed to build $SERVICE"
        exit 1
    fi
    
    log_info "$SERVICE built successfully"
    
    # Tag for ECR
    local ECR_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO:$IMAGE_TAG"
    docker tag "$REPO:$IMAGE_TAG" "$ECR_IMAGE"
    
    # Push to ECR
    log_info "Pushing $SERVICE to ECR..."
    if ! docker push "$ECR_IMAGE"; then
        log_error "Failed to push $SERVICE to ECR"
        exit 1
    fi
    
    log_info "$SERVICE pushed successfully"
    log_info "Image: $ECR_IMAGE"
    
    # Get image digest
    local DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$ECR_IMAGE" 2>/dev/null || echo "")
    if [ -n "$DIGEST" ]; then
        log_info "Digest: $DIGEST"
    fi
}

# Ensure repositories exist
ensure_repo "$REPO_BACKEND"
ensure_repo "$REPO_FRONTEND"

# Build and push backend
build_and_push "Backend" "$REPO_BACKEND" "./backend"

# Build and push frontend
build_and_push "Frontend" "$REPO_FRONTEND" "./frontend"

log_info "=========================================="
log_info "All images built and pushed successfully!"
log_info "=========================================="
log_info ""
log_info "Next steps:"
log_info "  1. Deploy to environment: ./deploy.sh <env> $IMAGE_TAG"
log_info "  2. Verify deployment: kubectl get pods -n <env>"
log_info ""
