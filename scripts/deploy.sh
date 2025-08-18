#!/bin/bash

# GitOps Deployment Script for Midil Labs Infrastructure
# This script helps deploy and manage the GitOps infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ARGOCD_NAMESPACE="argocd"
REPO_URL="https://github.com/midil-labs/infra-k8s.git"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    
    # Check if argocd CLI is installed
    if ! command -v argocd &> /dev/null; then
        log_warn "argocd CLI is not installed. Install it for better management."
    fi
    
    # Check if we can connect to the cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

deploy_namespaces() {
    log_info "Deploying namespaces..."
    kubectl apply -f k8s-apps/namespaces/
    log_info "Namespaces deployed successfully"
}

deploy_argocd_apps() {
    log_info "Deploying ArgoCD applications..."
    
    # Deploy in order of dependencies
    kubectl apply -f k8s-apps/argocd/namespaces-app.yaml
    kubectl apply -f k8s-apps/argocd/sealed-secrets-app.yaml
    kubectl apply -f k8s-apps/argocd/secrets/container-registry/registry-secrets.yaml
    kubectl apply -f k8s-apps/argocd/secrets/onekg-backend/onekg-backend-secrets.yaml
    kubectl apply -f k8s-apps/argocd/container-registry/harbor-app.yaml
    kubectl apply -f k8s-apps/argocd/onekg-backend/notification.yaml
    
    log_info "ArgoCD applications deployed successfully"
}

sync_applications() {
    if command -v argocd &> /dev/null; then
        log_info "Syncing ArgoCD applications..."
        
        # Wait for applications to be created
        sleep 10
        
        # Sync applications
        argocd app sync namespaces
        argocd app sync sealed-secrets
        argocd app sync registry-secrets
        argocd app sync harbor
        argocd app sync notification
        
        log_info "Applications synced successfully"
    else
        log_warn "argocd CLI not available. Applications will sync automatically."
    fi
}

check_status() {
    if command -v argocd &> /dev/null; then
        log_info "Checking application status..."
        argocd app list
    else
        log_info "Checking Kubernetes resources..."
        kubectl get applications -n argocd
        kubectl get namespaces | grep -E "(harbor|onekg-backend|sealed-secrets)"
    fi
}

cleanup() {
    log_warn "Cleaning up ArgoCD applications..."
    kubectl delete -f k8s-apps/argocd/ --ignore-not-found=true
    log_info "Cleanup completed"
}

# Main script
case "${1:-deploy}" in
    "deploy")
        check_prerequisites
        deploy_namespaces
        deploy_argocd_apps
        sync_applications
        check_status
        log_info "Deployment completed successfully!"
        ;;
    "status")
        check_status
        ;;
    "cleanup")
        cleanup
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [deploy|status|cleanup|help]"
        echo ""
        echo "Commands:"
        echo "  deploy   - Deploy the entire GitOps infrastructure (default)"
        echo "  status   - Check the status of deployed applications"
        echo "  cleanup  - Remove all ArgoCD applications"
        echo "  help     - Show this help message"
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
