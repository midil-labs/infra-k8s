#!/bin/bash

# OneKG Infrastructure Deployment Script
# Manages deployment of the GitOps infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
deploy_project() {
    echo -e "${GREEN}🚀 Deploying OneKG platform project...${NC}"
    
    echo "1. Deploying project definition..."
    kubectl apply -f argocd-apps/argocd/infrastructure/onekg-project-app.yaml
    
    echo -e "${GREEN}✅ Project definition deployed${NC}"
    echo -e "${YELLOW}📊 Waiting for project to be created...${NC}"
    sleep 10
}

deploy_infrastructure() {
    echo -e "${GREEN}🚀 Deploying infrastructure components...${NC}"
    
    echo "1. Deploying namespaces..."
    kubectl apply -f argocd-apps/argocd/infrastructure/namespaces-app.yaml
    
    echo "2. Deploying sealed secrets..."
    kubectl apply -f argocd-apps/argocd/infrastructure/sealed-secrets-app.yaml
    
    echo -e "${GREEN}✅ Infrastructure components deployed${NC}"
}

deploy_platform() {
    echo -e "${GREEN}🚀 Deploying OneKG platform...${NC}"
    
    echo "1. Deploying platform application..."
    kubectl apply -f argocd-apps/argocd/onekg-platform-app.yaml
    
    echo -e "${GREEN}✅ Platform deployed${NC}"
    echo -e "${YELLOW}📊 Check status with: argocd app get onekg-platform${NC}"
}

check_status() {
    echo -e "${GREEN}📊 Checking deployment status...${NC}"
    
    echo "ArgoCD Applications:"
    argocd app list
    
    echo ""
    echo "Platform Status:"
    argocd app get onekg-platform
}

cleanup() {
    echo -e "${YELLOW}🧹 Cleaning up deployments...${NC}"
    
    echo "1. Removing platform application..."
    kubectl delete -f argocd-apps/argocd/onekg-platform-app.yaml --ignore-not-found=true
    
    echo "2. Removing infrastructure applications..."
    kubectl delete -f argocd-apps/argocd/infrastructure/ --ignore-not-found=true
    
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

# Main script logic
case "${1:-help}" in
    "deploy")
        deploy_project
        deploy_infrastructure
        deploy_platform
        ;;
    "project")
        deploy_project
        ;;
    "infrastructure")
        deploy_infrastructure
        ;;
    "platform")
        deploy_platform
        ;;
    "status")
        check_status
        ;;
    "cleanup")
        cleanup
        ;;
    "help"|*)
        echo "OneKG Infrastructure Deployment Script"
        echo "====================================="
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  deploy         - Deploy entire infrastructure"
        echo "  project        - Deploy only project definition"
        echo "  infrastructure - Deploy only infrastructure components"
        echo "  platform       - Deploy only platform"
        echo "  status         - Check deployment status"
        echo "  cleanup        - Remove all deployments"
        echo "  help           - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 deploy      # Deploy everything"
        echo "  $0 status      # Check status"
        echo "  $0 cleanup     # Remove deployments"
        ;;
esac
