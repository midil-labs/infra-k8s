
# infra-k8s

Kubernetes manifests and Helm apps for the **OneKG Platform**, managed by **Argo CD** using the _App-of-Apps_ pattern.

This repository currently deploys the `checkin` service using the shared **Midil** Helm chart, with configuration, secrets (via **SealedSecrets**), and optional container registry authentication for GHCR.

---

## Overview

The `infra-k8s` repo provides a standardized, GitOps-driven deployment pipeline for all OneKG microservices.  
Each service (e.g., `checkin`) is managed as a Helm application tracked by Argo CD.  
Argo CD continuously syncs this repository’s manifests into the cluster, ensuring declarative, version-controlled infrastructure.

The **Midil chart** serves as a shared base chart for all OneKG services — providing common templates for:

- Deployments
- Services
- IngressRoute (Traefik)
- Observability (optional)
- Environment configuration

---

## Contents

| Path                              | Description                                      |
|------------------------------------|--------------------------------------------------|
| `apps/project.yaml`                | Argo CD AppProject definition for platform apps  |
| `app-of-apps.yaml`                 | Root Argo CD Application (discovers apps in `apps/`) |
| `apps/checkin/`                    | Argo CD Application (Helm) for `checkin`         |
| `apps/checkin/templates/*.secret.yaml` | SealedSecrets for app secrets and registry auth  |
| `k3s-registries.yaml`              | Optional containerd registry auth for k3s nodes   |

### Repository Layout

```text
apps/
  project.yaml                   # Argo CD AppProject for platform apps
  checkin/
    application.yaml             # Argo CD Application (Helm) for checkin
    Chart.yaml                   # Local Helm chart (depends on midil)
    values.yaml                  # Values passed to the midil chart
    templates/
      config.yaml                # ConfigMap with service configuration
      ghcr.secret.yaml           # SealedSecret for GHCR pull secret
      checkin.secret.yaml        # SealedSecret with app secrets
app-of-apps.yaml                 # Root Argo CD Application to discover apps/
k3s-registries.yaml              # Optional containerd registry auth (k3s)
```

---

## Dependencies

#### 🧠 What is midil?

**Midil** is a shared Helm chart that provides common deployment templates for all OneKG microservices, including:

- Standardized Deployment and Service specs
- Consistent Ingress configuration
- Environment variable templates
- Built-in observability and health probes

Each microservice (e.g., `checkin`, `notifications`, etc.) imports midil as a subchart to maintain uniformity across environments.

---

## Prerequisites

Before deploying, ensure you have:

- `kubectl` v1.28+
- `helm` v3+
- A running Kubernetes cluster (k3s, k3d, kind, or managed)
- **Argo CD** installed (`argocd` namespace)
- **Bitnami Sealed Secrets** controller installed (`sealed-secrets` namespace)
- Access to pull images from `ghcr.io/midil-labs`

> **Note:**
>
> - k3s ships with Traefik, which the Midil chart can use via Traefik `IngressRoute`.
> - If using a different ingress controller, update `apps/checkin/values.yaml` accordingly.

---

## Quick Start

### 1. Install Argo CD

```bash
kubectl create namespace argocd || true
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --values - <<'EOF'
server:
  insecure: true
  service:
    type: ClusterIP
EOF

# Verify installation
kubectl get pods -n argocd
```

### 2. Install Sealed Secrets

```bash
kubectl create namespace sealed-secrets || true
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm upgrade --install sealed-secrets-controller sealed-secrets/sealed-secrets \
  --namespace sealed-secrets \
  --set-string fullnameOverride=sealed-secrets-controller

# Verify controller
kubectl get pods -n sealed-secrets
```

### 3. Bootstrap Argo CD with this repository

Ensure the `targetRevision` in `app-of-apps.yaml` points to the branch you want Argo CD to track (e.g., `my-branch`):

```bash
kubectl apply -f apps/project.yaml
kubectl apply -f app-of-apps.yaml
```

Argo CD will automatically discover and create the `checkin` application from `apps/checkin/application.yaml`.

---

## Secrets and Image Pull

This repo includes **SealedSecrets** for:

- **GHCR pull secret:** `apps/checkin/templates/ghcr.secret.yaml` (name: `ghcr-secret`)
- **App secrets:** `apps/checkin/templates/checkin.secret.yaml` (name: `checkin-secrets`)

These are applied automatically when the Helm chart is synced.

### Regenerate GHCR Pull Secret

**Requirements:** `kubeseal` CLI and Sealed Secrets controller running.

```bash
export GITHUB_USERNAME=your-gh-username
export GITHUB_TOKEN=ghp_xxx_or_pat_with_read:packages

kubectl -n onekg-checkin create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username="$GITHUB_USERNAME" \
  --docker-password="$GITHUB_TOKEN" \
  --dry-run=client -o yaml | \
kubeseal \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets \
  --format=yaml \
  --namespace onekg-checkin \
  --name ghcr-secret \
  > apps/checkin/templates/ghcr.secret.yaml
```

### Regenerate Application Secret

Replace example literals as needed:

```bash
kubectl -n onekg-checkin create secret generic checkin-secrets \
  --from-literal=AWS_ACCESS_KEY_ID=AKIA... \
  --from-literal=AWS_SECRET_ACCESS_KEY=*** \
  --from-literal=MIDIL__API__DATABASE__URI=mongodb://mongo:27017 \
  --from-literal=MIDIL__API__NOTIFICATION__TOKEN=*** \
  --dry-run=client -o yaml | \
kubeseal \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets \
  --format=yaml \
  --namespace onekg-checkin \
  --name checkin-secrets \
  > apps/checkin/templates/checkin.secret.yaml
```

> ⚠️ **Important:**  
> Never commit raw secrets — only the sealed versions generated above.

---

## Configuration

Key configuration values are defined in `apps/checkin/values.yaml`:

| Key                             | Description                                 |
|---------------------------------|---------------------------------------------|
| `midil.image.*`                 | Image registry, name, and tag/digest        |
| `midil.ingressRoute.*`          | Traefik host, entry points, and path prefix |
| `midil.service.http.targetPort` | Container port                              |
| `templates/config.yaml`         | Service ConfigMap and environment variables |

Argo CD will automatically reconcile updates when you modify values (if auto-sync is enabled).

---

## Verifying Deployment

**Check Argo CD apps:**

```bash
kubectl -n argocd get applications
```

**Check workload:**

```bash
kubectl -n onekg-checkin get pods,svc
```

**Port-forward to test locally:**

```bash
kubectl -n onekg-checkin port-forward svc/checkin-service 8080:80
curl -i http://localhost:8080/apis/v1/checkin/docs
```

**Test via Traefik ingress:**

```bash
sudo sh -c 'echo "127.0.0.1 local.midil.io" >> /etc/hosts'
curl -H 'Host: local.midil.io' -i http://127.0.0.1/apis/v1/checkin
```

---

## Add a New App

Argo CD discovers applications automatically via `app-of-apps.yaml`, scanning `apps/**/application.yaml`.

To add a new app (e.g., `myapp`):

### 1. Create a directory and application manifest

```bash
mkdir -p apps/myapp/templates
```

Create `apps/myapp/application.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: onekg-platform
  source:
    repoURL: https://github.com/midil-labs/infra-k8s.git
    targetRevision: my-branch
    path: apps/myapp
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: onekg-myapp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 2. Add a Helm chart depending on Midil

Create `apps/myapp/Chart.yaml`:

```yaml
apiVersion: v2
name: myapp-service
description: MyApp Service
type: application
version: 0.1.0
appVersion: "1.0"
dependencies:
  - name: midil
    version: 0.1.0
    repository: "https://midil-labs.github.io/helm-charts"
```

Create `apps/myapp/values.yaml`:

```yaml
midil:
  serviceName: myapp
  platform: onekg
  image:
    registry: ghcr.io/midil-labs
    service: onekg-myapp-api
    tag: 0.1.0-dev
    pullSecrets:
      - name: ghcr-secret
    createPullSecret: false
  ingressRoute:
    enabled: true
    host: "local.midil.io"
    entryPoints: ["websecure"]
    route:
      pathPrefix: "/apis/v1/myapp"
      servicePort: 80
    tls:
      enabled: false
  service:
    http:
      targetPort: 8080
```

### 3. Add optional config and secrets

- Optional ConfigMap: `apps/myapp/templates/config.yaml`
- Reuse the global pull secret `ghcr-secret` or generate one per namespace.
- Create and seal app secrets as needed using `kubeseal`.

### 4. Update AppProject destinations

Add your new namespace under `spec.destinations` in `apps/project.yaml`:

```yaml
spec:
  destinations:
    - namespace: onekg-myapp
      server: https://kubernetes.default.svc
```

### 5. Commit and push

Once merged, the App-of-Apps will detect your new app and sync it automatically.

---

## Conventions

| Concept                 | Format           |
|-------------------------|------------------|
| **Namespace**           | `onekg-<app>`    |
| **Application name**    | `<app>`          |
| **Chart name**          | `<app>-service`  |
| **Pull secret**         | `ghcr-secret`    |
| **App secret**          | `<app>-secrets`  |
| **App config**          | `<app>-config`   |
| **Ingress path prefix** | `/apis/v1/<app>` |
| **Local host**          | `local.midil.io` |

---

## Local Development & Testing

### Using Argo CD (recommended)

- Work on a feature branch.
- Set `targetRevision` in `app-of-apps.yaml` to that branch.
- Push and let Argo CD deploy automatically.

### Using Helm directly (for quick testing)

```bash
cd apps/myapp
helm dependency update
helm upgrade --install myapp . -n onekg-myapp-dev --create-namespace
kubectl -n onekg-myapp-dev port-forward svc/myapp-service 8080:80
```

Visit `http://localhost:8080/apis/v1/myapp`, then clean up:

```bash
helm uninstall myapp -n onekg-myapp-dev
```

---

## Optional: k3s Containerd Registry Auth

If you prefer node-level containerd authentication (instead of imagePullSecrets):

```bash
sudo mkdir -p /etc/rancher/k3s
sudo cp k3s-registries.yaml /etc/rancher/k3s/registries.yaml
sudo sed -i '' 's/<USERNAME>/your-gh-username/' /etc/rancher/k3s/registries.yaml
sudo sed -i '' 's/<PASSWORD>/your-gh-token/' /etc/rancher/k3s/registries.yaml
sudo systemctl restart k3s || sudo systemctl restart k3s-agent
```

When using this approach, set:

```yaml
midil.image.createPullSecret: false
midil.image.pullSecrets: []
```

---

## Troubleshooting

| Issue                             | Likely Cause                                  | Fix                                                             |
|------------------------------------|-----------------------------------------------|-----------------------------------------------------------------|
| **Image pull failures**           | Missing or invalid GHCR credentials           | Ensure `ghcr-secret` exists in namespace or use containerd auth |
| **SealedSecrets not decrypting**  | Name/namespace mismatch or missing controller | Verify controller is running and flags match                    |
| **Ingress 404 / SSL issues**      | Misconfigured Traefik or hosts entry          | Check Traefik CRDs, entry points, and `/etc/hosts`              |
| **Argo app out of sync**          | Manual drift or sync error                    | Run `kubectl -n argocd describe application <app>`              |

---

## Updating Images

To deploy a new image:

1. Edit `apps/checkin/values.yaml`
2. Update `midil.image.tag` (or digest)
3. Commit and push — Argo CD will automatically sync.

---

## References

- [Argo CD App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/app-of-apps/)
- [Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [Helm Dependency Management](https://helm.sh/docs/topics/charts/#chart-dependencies)

---

## Contributing

- Make changes in a feature branch.
- Validate manifests locally:

  ```bash
  helm lint apps/checkin
  kubectl apply --dry-run=client -f apps/checkin/application.yaml
  ```

- Ensure all new apps follow conventions and naming standards.
- Submit a PR; Argo CD will reconcile after merge.

---

### Architecture Diagram (App-of-Apps Overview)

```
Argo CD
 ├── app-of-apps (root)
 │     ├── project.yaml
 │     ├── apps/
 │     │     ├── checkin/
 │     │     ├── myapp/
 │     │     └── ...
 │     └── managed via GitOps (syncs automatically)
```

---

**Maintained by:** [Midil Labs](https://github.com/midil-labs)  
**Purpose:** Declarative infrastructure for OneKG platform services under Argo CD management.
