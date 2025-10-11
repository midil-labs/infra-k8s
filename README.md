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

`kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller --format=yaml -n onekg-checkin --name checkin-secrets < /Users/chael/Desktop/CODE/midil/infra-k8s/apps/checkin/templates/raw.secret.yaml > //Users/chael/Desktop/CODE/midil/infra-k8s/apps/checkin/templates/checkin.secret.yaml`


```kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username="$GITHUB_USERNAME" \
  --docker-password="$GITHUB_TOKEN" \
  --namespace onekg-checkin \
  --dry-run=client -o yaml | \
kubeseal \
  --format=yaml \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets \
  --namespace onekg-checkin \
  > /Users/chael/Desktop/CODE/midil/infra-k8s/ghcr.secret.yaml```