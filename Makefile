# --- GLOBAL CONFIG ---
CLUSTER_CONTEXT ?= k3s-default
ARGOCD_NAMESPACE = argocd
APP ?= all
APPS := $(sort $(notdir $(patsubst %/,%,$(dir $(wildcard apps/*/application.yaml)))))

# Determine which apps to operate on
ifeq ($(APP),all)
APPS_SELECTED := $(APPS)
else
ifeq ($(filter $(APP),$(APPS)),$(APP))
APPS_SELECTED := $(APP)
else
$(error APP '$(APP)' not found. Valid options: $(APPS))
endif
endif

REGISTRY_SERVER = ghcr.io
REGISTRY_USERNAME ?= $(shell echo $$GHCR_USER)
REGISTRY_PASSWORD ?= $(shell echo $$GHCR_PAT)

GREEN := \033[0;32m
NC := \033[0m

# --- MAIN TARGET ---
.PHONY: all
all: check-prereqs setup-argocd-ns install-argocd create-namespaces create-ghcr-secrets update-helm-deps bootstrap
	@echo "$(GREEN)✅ Environment setup complete.$(NC)"

check-prereqs:
	@command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found"; exit 1; }
	@command -v helm >/dev/null 2>&1 || { echo "❌ helm not found"; exit 1; }
	@if [ -z "$(REGISTRY_USERNAME)" ] || [ -z "$(REGISTRY_PASSWORD)" ]; then \
	  echo "❌ GHCR_USER or GHCR_PAT not set in environment"; exit 1; \
	fi

setup-argocd-ns:
	kubectl create namespace $(ARGOCD_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -

install-argocd:
	@echo "$(GREEN)> Installing Argo CD via Helm$(NC)"
	helm repo add argo https://argoproj.github.io/argo-helm
	helm upgrade --install argocd argo/argo-cd \
	  --namespace $(ARGOCD_NAMESPACE) \
	  --create-namespace \
	  --set server.service.type=ClusterIP
	kubectl wait --for=condition=available --timeout=180s deployment/argocd-server -n $(ARGOCD_NAMESPACE)

create-namespaces:
	@for ns in $(APPS_SELECTED); do \
	  echo "$(GREEN)> Creating namespace onekg-$$ns$(NC)"; \
	  kubectl create namespace onekg-$$ns --dry-run=client -o yaml | kubectl apply -f -; \
	done

create-ghcr-secrets:
	@for ns in $(APPS_SELECTED); do \
	  echo "$(GREEN)> Creating GHCR secret in onekg-$$ns$(NC)"; \
	  kubectl create secret docker-registry ghcr-secret \
	    --namespace onekg-$$ns \
	    --docker-server=$(REGISTRY_SERVER) \
	    --docker-username=$(REGISTRY_USERNAME) \
	    --docker-password=$(REGISTRY_PASSWORD) \
	    --dry-run=client -o yaml | kubectl apply -f -; \
	  kubectl patch serviceaccount default -n onekg-$$ns \
	    -p '{"imagePullSecrets": [{"name": "ghcr-secret"}]}' || true; \
	done

update-helm-deps:
	@for app in $(APPS_SELECTED); do \
	  echo "$(GREEN)> Updating Helm deps for $$app$(NC)"; \
	  cd apps/$$app && helm dependency update; \
	done

bootstrap:
	@if [ "$(APP)" = "all" ]; then \
	  kubectl apply -f app-of-apps.yaml -n $(ARGOCD_NAMESPACE); \
	else \
	  kubectl apply -f apps/project.yaml -n $(ARGOCD_NAMESPACE); \
	  kubectl apply -f apps/$(APP)/application.yaml -n $(ARGOCD_NAMESPACE); \
	fi

status:
	@kubectl get applications -n $(ARGOCD_NAMESPACE)
	@for ns in $(APPS_SELECTED); do \
	  echo "$(GREEN)> Pods in onekg-$$ns$(NC)"; \
	  kubectl get pods -n onekg-$$ns; \
	done

clean:
	@echo "$(GREEN)> Cleaning up$(NC)"
	@for ns in $(APPS); do \
	  kubectl delete namespace onekg-$$ns || true; \
	done
	kubectl delete namespace $(ARGOCD_NAMESPACE) || true
