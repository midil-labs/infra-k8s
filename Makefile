# Makefile for OneKG Infrastructure
# Provides convenient commands for managing the GitOps infrastructure

.PHONY: help lint validate deploy clean status logs

# Default target
help:
	@echo "OneKG Infrastructure Management"
	@echo "=============================="
	@echo ""
	@echo "Available commands:"
	@echo "  lint      - Lint all YAML files"
	@echo "  validate  - Validate naming conventions"
	@echo "  deploy    - Deploy infrastructure"
	@echo "  clean     - Clean up deployments"
	@echo "  status    - Check deployment status"
	@echo "  logs      - View application logs"
	@echo "  help      - Show this help message"

# Lint all YAML files
lint:
	@echo "🔍 Linting YAML files..."
	@for file in $$(find argocd-apps -name "*.yaml" -o -name "*.yml"); do \
		echo "Linting $$file..."; \
		yamllint "$$file" || exit 1; \
	done
	@echo "✅ All YAML files passed linting"

# Validate naming conventions
validate:
	@echo "🔍 Validating naming conventions..."
	@./scripts/validate-naming.sh

# Deploy infrastructure
deploy:
	@echo "🚀 Deploying OneKG infrastructure..."
	@echo "1. Deploying infrastructure components..."
	kubectl apply -f argocd-apps/argocd/infrastructure/
	@echo "2. Deploying platform..."
	kubectl apply -f argocd-apps/argocd/onekg-platform-app.yaml
	@echo "✅ Deployment initiated"
	@echo "📊 Check status with: make status"

# Clean up deployments
clean:
	@echo "🧹 Cleaning up deployments..."
	kubectl delete -f argocd-apps/argocd/ --ignore-not-found=true
	@echo "✅ Cleanup completed"

# Check deployment status
status:
	@echo "📊 Checking deployment status..."
	@echo "ArgoCD Applications:"
	argocd app list
	@echo ""
	@echo "Platform Status:"
	argocd app get onekg-platform

# View application logs
logs:
	@echo "📋 Viewing application logs..."
	@echo "Available applications:"
	@echo "  - onekg-platform"
	@echo "  - onekg-namespaces"
	@echo "  - onekg-sealed-secrets"
	@echo "  - onekg-secrets"
	@echo ""
	@echo "Usage: argocd app logs <app-name>"

# Quick validation
quick-validate:
	@echo "🔍 Quick validation..."
	yamllint argocd-apps/ sealed-secrets/; \
	@echo "✅ Quick validation completed"
