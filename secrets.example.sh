set -euo pipefail

# Configure env vars locally (do NOT commit this file after renaming to secrets.sh)
# export GHCR_SERVER=ghcr.io
# export GHCR_USERNAME="your-ghcr-username"
# export GHCR_TOKEN="your-ghcr-token"

GHCR_SERVER=${GHCR_SERVER:-ghcr.io}
GHCR_USERNAME=${GHCR_USERNAME:?GHCR_USERNAME env var is required}
GHCR_TOKEN=${GHCR_TOKEN:?GHCR_TOKEN env var is required}

# onekg-checkin GHCR secret
kubectl -n onekg-checkin create secret docker-registry ghcr-secret \
  --docker-server="${GHCR_SERVER}" \
  --docker-username="${GHCR_USERNAME}" \
  --docker-password="${GHCR_TOKEN}" \
  --dry-run=client -o yaml | \
kubeseal \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  --format=yaml \
  --namespace onekg-checkin \
  --name ghcr-secret \
  > apps/checkin/templates/ghcr.secret.yaml

# onekg-notification GHCR secret
kubectl -n onekg-notification create secret docker-registry ghcr-secret \
  --docker-server="${GHCR_SERVER}" \
  --docker-username="${GHCR_USERNAME}" \
  --docker-password="${GHCR_TOKEN}" \
  --dry-run=client -o yaml | \
kubeseal \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  --format=yaml \
  --namespace onekg-notification \
  --name ghcr-secret \
  > apps/notification/templates/ghcr.secret.yaml

# onekg-user GHCR secret
kubectl -n onekg-user create secret docker-registry ghcr-secret \
  --docker-server="${GHCR_SERVER}" \
  --docker-username="${GHCR_USERNAME}" \
  --docker-password="${GHCR_TOKEN}" \
  --dry-run=client -o yaml | \
kubeseal \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  --format=yaml \
  --namespace onekg-user \
  --name ghcr-secret \
  > apps/user/templates/ghcr.secret.yaml

# Example app secrets (set in your shell, not here)
# export AWS_ACCESS_KEY_ID=...
# export AWS_SECRET_ACCESS_KEY=...
# export MIDIL__API__DATABASE__URI=...
# export MIDIL__API__NOTIFICATION__TOKEN=...
# export MIDIL__API__NOTIFICATION__SMS__API_KEY=...
# export MIDIL__API__NOTIFICATION__SMS__API_SECRET=...
# export MIDIL__API__NOTIFICATION__PUSH__ONESIGNAL__API_KEY=...
# export MIDIL__API__NOTIFICATION__PUSH__ONESIGNAL__APP_ID=...

# Example: create sealed secret for checkin (uncomment after exporting vars)
# kubectl -n onekg-checkin create secret generic checkin-secrets \
#   --from-literal=AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
#   --from-literal=AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
#   --from-literal=MIDIL__API__DATABASE__URI="$MIDIL__API__DATABASE__URI" \
#   --from-literal=MIDIL__API__NOTIFICATION__TOKEN="$MIDIL__API__NOTIFICATION__TOKEN" \
#   --dry-run=client -o yaml | \
# kubeseal \
#   --controller-name=sealed-secrets-controller \
#   --controller-namespace=kube-system \
#   --format=yaml \
#   --namespace=onekg-checkin \
#   --name=checkin-secrets \
#   > apps/checkin/templates/checkin.secret.yaml

# Example: notification service
# kubectl -n onekg-notification create secret generic notification-secrets \
#   --from-literal=MIDIL__API__NOTIFICATION__SMS__API_KEY="$MIDIL__API__NOTIFICATION__SMS__API_KEY" \
#   --from-literal=MIDIL__API__NOTIFICATION__SMS__API_SECRET="$MIDIL__API__NOTIFICATION__SMS__API_SECRET" \
#   --from-literal=MIDIL__API__NOTIFICATION__PUSH__ONESIGNAL__API_KEY="$MIDIL__API__NOTIFICATION__PUSH__ONESIGNAL__API_KEY" \
#   --from-literal=MIDIL__API__NOTIFICATION__PUSH__ONESIGNAL__APP_ID="$MIDIL__API__NOTIFICATION__PUSH__ONESIGNAL__APP_ID" \
#   --dry-run=client -o yaml | \
# kubeseal \
#   --controller-name=sealed-secrets-controller \
#   --controller-namespace=kube-system \
#   --format=yaml \
#   --namespace=onekg-notification \
#   --name=notification-secrets \
#   > apps/notification/templates/notification.secret.yaml

# Example: user service
# kubectl -n onekg-user create secret generic user-secrets \
#   --from-literal=MIDIL__API__DATABASE__URI="$MIDIL__API__DATABASE__URI" \
#   --dry-run=client -o yaml | \
# kubeseal \
#   --controller-name=sealed-secrets-controller \
#   --controller-namespace=kube-system \
#   --format=yaml \
#   --namespace=onekg-user \
#   --name=user-secrets \
#   > apps/user/templates/user.secret.yaml
