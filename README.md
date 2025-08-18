# GitOps Infrastructure for Midil Labs

This repository contains the GitOps infrastructure for Midil Labs, managed with ArgoCD using the **App of Apps pattern**.

## 🏗️ Architecture Overview

This infrastructure follows GitOps principles using ArgoCD's App of Apps pattern to manage the entire OneKG microservices platform declaratively.

```
infra-k8s/
├── app-of-apps/                     # 🆕 Parent application (manages all microservices)
│   ├── Chart.yaml
│   ├── values.yaml                  # Global platform configuration
│   └── templates/
│       └── applications.yaml        # Generates child ArgoCD apps
├── services/                        # 🆕 Shared service templates
│   ├── Chart.yaml
│   ├── values.yaml                  # Default service configuration  
│   └── templates/                   # Common Kubernetes resources
├── service-configs/                 # 🆕 Individual service configurations
│   └── notification/
│       └── values.yaml              # Service-specific overrides
├── argocd-apps/                    # 🆕 ArgoCD applications (renamed from k8s-apps)
│   ├── argocd/                     # ArgoCD application definitions
│   │   ├── infrastructure/         # Infrastructure applications
│   │   │   ├── namespaces-app.yaml     # Namespace management
│   │   │   ├── sealed-secrets-app.yaml # Secret management
│   │   │   └── onekg-secrets-app.yaml  # Platform secrets
│   │   └── onekg-platform-app.yaml     # 🎯 App of Apps (manages all microservices)
│   └── infrastructure/             # 🆕 Reorganized infrastructure components
│       ├── namespaces/             # Namespace definitions
│       ├── sealed-secrets/         # Encrypted secrets
│       └── secrets/                # Platform secrets
├── sealed-secrets/                  # Legacy location (moved to argocd-apps/infrastructure/)
└── k3s-registries.yaml              # K3s registry configuration
```

## Applications

### OneKG Microservices Platform (App of Apps)
- **Pattern**: App of Apps with centralized configuration
- **Services**: notification (only service currently available)
- **Endpoint**: `api.onekg.midil.io/v1/notification/`
- **Features**: Shared templates, individual configurations, ready for scaling

### Infrastructure Components
- **Namespaces**: Automated namespace creation (`onekg-backend`, `sealed-secrets`)
- **Sealed Secrets**: Encrypted secret management
- **Container Registry Secret**: GHCR authentication for private images

## Getting Started

### Prerequisites
- Kubernetes cluster (K3s recommended)
- ArgoCD installed and configured
- kubeseal for secret encryption
- Helm 3.x

## 🚀 Deployment

### Quick Start (Development)
```bash
# 1. Deploy infrastructure (namespaces, secrets, harbor)
kubectl apply -f argocd-apps/argocd/infrastructure/

# 2. Deploy the platform (manages all microservices)
kubectl apply -f argocd-apps/argocd/onekg-platform-app.yaml

# 3. Check platform status
argocd app get onekg-platform
```

### Adding New Services
```bash
# 1. Enable service in app-of-apps/values.yaml
services:
  payment:
    enabled: true  # Just change this!

# 2. Create service-configs/payment/values.yaml
serviceName: payment
service:
  targetPort: 8002
  
# 3. Commit and push - ArgoCD deploys automatically!
```

### Secret Management
Secrets are encrypted using Sealed Secrets. To add new secrets:

1. Create the unencrypted secret YAML
2. Encrypt using kubeseal:
   ```bash
   kubeseal --format=yaml < secret.yaml > sealed-secret.yaml
   ```
3. Commit the sealed secret to the repository

## Directory Structure

### ArgoCD Applications (`argocd-apps/argocd/`)
- `namespaces-app.yaml` - Manages namespace creation
- `sealed-secrets-app.yaml` - Manages sealed secrets deployment
- `onekg-secrets-app.yaml` - Manages platform secrets
- `onekg-platform-app.yaml` - App of Apps (manages all microservices)

### Infrastructure Components (`argocd-apps/infrastructure/`)
- `namespaces/` - Namespace definitions
- `sealed-secrets/` - Encrypted secrets using Sealed Secrets
- `secrets/` - Platform-specific secrets

### Service Templates (`services/`)
- Shared Kubernetes resource templates
- Common configuration patterns
- Reusable across all microservices

### Service Configurations (`service-configs/`)
- Individual service customizations
- Service-specific overrides
- Environment-specific settings

## Naming Conventions

### Applications
- All applications use `onekg-` prefix: `onekg-platform`, `onekg-namespaces`, etc.
- Consistent labeling with `app.kubernetes.io/part-of: onekg-platform`
- Component labels: `platform.onekg.io/component: infrastructure|platform|microservice`

### Services
- Service names: `notification`, `payment`, etc.
- Consistent helper functions: `onekg-service.*`, `onekg-platform.*`
- Standard Kubernetes resource naming

### Directories
- Clear, descriptive names: `argocd-apps`, `app-of-apps`, `services`
- Logical organization: `infrastructure/`, `platform/`
- Consistent structure across components

## Contributing

1. Follow the established naming conventions
2. Use the shared service templates for new services
3. Add proper labels to all resources
4. Update documentation for any structural changes
5. Test changes in staging before production

## Support

For questions or issues, contact the DevOps team at devops@midil.io