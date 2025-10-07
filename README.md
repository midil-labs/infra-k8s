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