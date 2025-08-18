# OneKG Infrastructure - GitOps with ArgoCD

This repository contains the GitOps infrastructure for the OneKG platform, using ArgoCD for continuous deployment and Kubernetes for orchestration.

## 🏗️ Architecture

The infrastructure follows a modern GitOps approach with:

- **ArgoCD**: Declarative GitOps continuous delivery
- **Kubernetes**: Container orchestration
- **Traefik**: Ingress controller and API gateway
- **Helm**: Package management for Kubernetes applications
- **Sealed Secrets**: Encrypted secrets management

## 📁 Directory Structure

```
├── argocd-apps/                    # 🆕 ArgoCD applications (renamed from k8s-apps)
│   ├── argocd/                     # ArgoCD application definitions
│   │   ├── infrastructure/         # Infrastructure components
│   │   ├── projects/               # ArgoCD project definitions
│   │   └── onekg-platform-app.yaml # Main App of Apps
│   └── infrastructure/             # Infrastructure manifests
│       ├── namespaces/             # Namespace definitions
│       └── sealed-secrets/         # Encrypted secrets
├── app-of-apps/                    # App of Apps pattern
│   ├── templates/                  # Helm templates
│   └── values.yaml                 # Global configuration
├── services/                       # Shared service templates
├── service-configs/                # Service-specific configurations
└── scripts/                        # Deployment scripts
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster with ArgoCD installed
- `kubectl` configured
- `helm` (optional, for local testing)

### Deployment

1. **Deploy the entire platform**:
   ```bash
   ./scripts/deploy.sh deploy
   ```

2. **Check deployment status**:
   ```bash
   ./scripts/deploy.sh status
   ```

3. **Clean up**:
   ```bash
   ./scripts/deploy.sh cleanup
   ```

## 📊 Services

### Notification Service

- **Endpoint**: `onekg.midil.io/v1/notification/`
- **Health Check**: `onekg.midil.io/v1/notification/health`
- **Namespace**: `onekg-backend`
- **Replicas**: 3 (auto-scaling enabled)
- **Versioning**: API-level versioning (`/v1/`)

### API Versioning

The platform uses API-level versioning for clean, industry-standard URLs:
- **v1**: `onekg.midil.io/v1/notification/`
- **v2**: `onekg.midil.io/v2/notification/` (future)
- **FastAPI**: Handles versioning internally with `/v1/` and `/v2/` prefixes

## 🔧 Configuration

### Global Settings

- **Domain**: `onekg.midil.io`
- **TLS**: Cloudflare Universal SSL
- **CORS**: Configured for production origins
- **Monitoring**: Prometheus metrics enabled

### Service Configuration

Each service can be configured in `service-configs/<service-name>/values.yaml` with:
- Resource limits and requests
- Replica count
- Monitoring settings
- CORS configuration

## 🛠️ Development

### Adding a New Service

1. Create service configuration in `service-configs/<service-name>/`
2. Add service definition to `app-of-apps/values.yaml`
3. Deploy with `./scripts/deploy.sh deploy`

### Local Testing

```bash
# Port-forward to test service locally
kubectl port-forward service/notification 8080:80 -n onekg-backend

# Test health endpoint
curl http://localhost:8080/health
```

## 📈 Monitoring

- **Prometheus**: Metrics collection enabled
- **Health Checks**: Liveness and readiness probes configured
- **Logging**: Structured logging with service identification

## 🔒 Security

- **Sealed Secrets**: Encrypted secrets in Git
- **RBAC**: Role-based access control
- **Network Policies**: Pod-to-pod communication restrictions
- **Security Contexts**: Non-root containers

## 📝 Notes

- All changes are managed through GitOps
- ArgoCD automatically syncs changes from this repository
- Secrets are encrypted using Sealed Secrets
- TLS certificates are managed by Cloudflare Universal SSL