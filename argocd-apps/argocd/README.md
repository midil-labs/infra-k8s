# Clean ArgoCD Applications Directory

This directory now contains only the essential ArgoCD applications for the OneKG platform.

## Structure

```
argocd/
├── onekg-platform-app.yaml      # App of Apps - manages all microservices
├── infrastructure/              # Infrastructure applications
│   ├── namespaces-app.yaml     # Namespace management
│   ├── sealed-secrets-app.yaml # Secret management
│   └── harbor-app.yaml         # Container registry
└── README.md                   # This file
```

## Application Dependencies

1. **Infrastructure** (deploy first):
   - namespaces
   - sealed-secrets  
   - harbor

2. **Platform** (deploy after infrastructure):
   - onekg-platform (App of Apps)

## Deployment Order

```bash
# 1. Deploy infrastructure
kubectl apply -f argocd/infrastructure/

# 2. Deploy platform (manages all microservices)
kubectl apply -f argocd/onekg-platform-app.yaml
```

## Legacy Cleanup

The following legacy components have been removed:
- ❌ Individual service ArgoCD applications (onekg-backend/notification.yaml)
- ❌ Legacy Helm charts (charts/onekg-backend/notification/)
- ❌ Mixed ArgoCD directory structure
- ❌ Duplicate secret management applications

All microservices are now managed through the **App of Apps pattern** in `onekg-platform-app.yaml`.
