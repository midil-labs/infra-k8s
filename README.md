## infra-k8s

Kubernetes manifests and Helm apps for the OneKG platform, managed by Argo CD using an App-of-Apps pattern. This repository currently deploys the `checkin` service via the shared `midil` Helm chart, with configuration, secrets (via SealedSecrets), and optional container registry auth for GHCR.

### What this repo contains
- **Argo CD AppProject**: `apps/project.yaml`
- **Argo CD App-of-Apps**: `app-of-apps.yaml` (discovers apps in `apps/`)
- **`checkin` app (Helm chart)**: `apps/checkin/` (depends on `midil` chart)
- **SealedSecrets**: `apps/checkin/templates/*.secret.yaml`
- **Optional k3s registry config**: `k3s-registries.yaml`

### Repo layout
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

## Prerequisites
- kubectl v1.28+
- helm v3+
- A Kubernetes cluster (k3s/k3d, kind, or managed)
- Argo CD installed in the cluster (`argocd` namespace)
- Bitnami Sealed Secrets controller installed (`sealed-secrets` namespace)
- Access to pull images from `ghcr.io/midil-labs`

Notes:
- k3s ships with Traefik, which the `midil` chart can use via Traefik `IngressRoute`.
- If you use a different cluster ingress, adapt `apps/checkin/values.yaml` accordingly.

## Quick start
1) Install Argo CD (if not already installed)
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
```

2) Install Sealed Secrets (if not already installed)
```bash
kubectl create namespace sealed-secrets || true
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm upgrade --install sealed-secrets-controller sealed-secrets/sealed-secrets \
  --namespace sealed-secrets \
  --set-string fullnameOverride=sealed-secrets-controller
```

3) Bootstrap Argo CD with this repo
Ensure the `targetRevision` in `app-of-apps.yaml` points to the branch you want Argo CD to track (currently `apply-midil-charts`). Then apply the project and app-of-apps:
```bash
kubectl apply -f apps/project.yaml
kubectl apply -f app-of-apps.yaml
```

Argo CD will discover and create the `checkin` application from `apps/checkin/application.yaml` and sync the Helm chart.

## Secrets and image pull
This repo includes SealedSecrets for:
- GHCR image pull secret: `apps/checkin/templates/ghcr.secret.yaml` (name: `ghcr-secret`)
- App secrets: `apps/checkin/templates/checkin.secret.yaml` (name: `checkin-secrets`)

These will be applied automatically by the `checkin` Helm app. If you need to regenerate them with your own credentials, use the steps below.

### Regenerate GHCR pull secret
Requirements: `kubeseal` CLI and the Sealed Secrets controller running.
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

### Regenerate application secret
Provide the literals required by the app (replace example values):
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

Commit the updated sealed secret files. Do NOT commit any raw secrets.

## Configuration
The `checkin` app values are in `apps/checkin/values.yaml`. Notable settings:
- `midil.image.*`: image registry, name, and tag/digest
- `midil.ingressRoute.*`: Traefik host, entry points, path prefix
- `midil.service.http.targetPort`: container port
- `templates/config.yaml`: ConfigMap with service configuration and env vars

If you change values, Argo CD will reconcile automatically (if auto-sync is enabled).

## Verifying the deployment
Check that Argo CD apps are created and synced:
```bash
kubectl -n argocd get applications
```

Check that the `checkin` workload is running:
```bash
kubectl -n onekg-checkin get pods,svc
```

Port-forward the service and verify the API is reachable:
```bash
kubectl -n onekg-checkin port-forward svc/checkin-service 8080:80
# In another terminal
curl -i http://localhost:8080/apis/v1/checkin/docs
```

If using Traefik/IngressRoute and the default host `local.midil.io`, map it locally and test:
```bash
sudo sh -c 'echo "127.0.0.1 local.midil.io" >> /etc/hosts'
# Then hit via the ingress host (adjust scheme/port per your Traefik setup)
curl -H 'Host: local.midil.io' -i http://127.0.0.1/apis/v1/checkin
```

## Add a new app
Apps are discovered automatically by Argo CD via `app-of-apps.yaml` scanning `apps/**.yaml`. To add a new app (e.g., `myapp`):

1) Create the directory and Argo Application manifest
```bash
mkdir -p apps/myapp/templates
```

`apps/myapp/application.yaml`:
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
    targetRevision: apply-midil-charts
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

2) Add a Helm chart that depends on the shared `midil` chart

`apps/myapp/Chart.yaml`:
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

`apps/myapp/values.yaml` (adjust for your image and routes):
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
    pullSecretName: ghcr-secret

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

`apps/myapp/templates/config.yaml` (optional ConfigMap):
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  namespace: {{ .Release.Namespace }}
data:
  EXAMPLE: "value"
```

3) Secrets
- Reuse the global GHCR pull secret name `ghcr-secret` (or generate a new one per-namespace).
- Create an app secret named `myapp-secrets` if needed, and seal it with `kubeseal` using `--name myapp-secrets --namespace onekg-myapp`.

4) Allow the new namespace in the AppProject
Edit `apps/project.yaml` and add your namespace under `spec.destinations`:
```yaml
spec:
  destinations:
    - namespace: onekg-myapp
      server: https://kubernetes.default.svc
    # keep existing entries
```

5) Commit and push
Once merged, the App-of-Apps (`app-of-apps.yaml`) will detect `apps/myapp/application.yaml` and Argo CD will create and sync the app.

### Conventions
- **Namespace**: `onekg-<app>`
- **Application name**: `<app>`
- **Chart name**: `<app>-service`
- **Pull secret**: `ghcr-secret` (or app-specific)
- **App secret**: `<app>-secrets`
- **Ingress path prefix**: `/apis/v1/<app>`
- **Default host for local**: `local.midil.io`

## Local development and testing
Choose one of the following approaches:

- Using Argo CD (recommended):
  - Work on a feature branch, push changes, ensure `targetRevision` points to that branch if testing via Argo.
  - Argo will reconcile and deploy to your app namespace.

- Direct Helm install to a dev namespace (bypasses Argo):
```bash
cd apps/myapp
helm dependency update
helm upgrade --install myapp . -n onekg-myapp-dev --create-namespace
kubectl -n onekg-myapp-dev port-forward svc/myapp-service 8080:80
```
Visit `http://localhost:8080/apis/v1/myapp` (or your service’s docs/health path). When done, uninstall:
```bash
helm uninstall myapp -n onekg-myapp-dev
```

## Optional: k3s containerd registry auth
If you prefer node-level containerd auth (instead of an imagePullSecret), copy `k3s-registries.yaml` to your k3s node(s), set credentials, and restart k3s:
```bash
sudo mkdir -p /etc/rancher/k3s
sudo cp k3s-registries.yaml /etc/rancher/k3s/registries.yaml
sudo sed -i '' 's/<USERNAME>/your-gh-username/' /etc/rancher/k3s/registries.yaml
sudo sed -i '' 's/<PASSWORD>/your-gh-token/' /etc/rancher/k3s/registries.yaml
sudo systemctl restart k3s || sudo systemctl restart k3s-agent
```

When using this approach, you can set `midil.image.createPullSecret=false` and keep `midil.image.pullSecrets` empty.

## Troubleshooting
- **Image pull failures**: Ensure GHCR credentials are correct and either the SealedSecret `ghcr-secret` exists in `onekg-checkin` or k3s containerd auth is configured.
- **SealedSecrets not decrypting**: Verify the controller is running in `sealed-secrets` and the `--name`/`--namespace` used with `kubeseal` match the manifest.
- **Ingress 404/SSL issues**: Check Traefik CRDs are installed, the `IngressRoute` host matches your DNS/hosts entry, and the entry points in values match your Traefik listeners. For quick testing, prefer port-forwarding.
- **Argo app out of sync**: `kubectl -n argocd describe application onekg-platform` and `checkin` for status and events.

## Updating images
To deploy a new image, edit `apps/checkin/values.yaml` and update `midil.image.tag` (optionally with digest). Commit and push; Argo CD will sync.
