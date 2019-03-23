#!/usr/bin/env bash

# Verify environment is provided
[[ -z "${CLOUDFLARE_EMAIL}" ]] && echo "environment variable 'CLOUDFLARE_EMAIL' missing" >&2 && exit 1
[[ -z "${CLOUDFLARE_TOKEN}" ]] && echo "environment variable 'CLOUDFLARE_TOKEN' missing" >&2 && exit 1
[[ -z "${CLUSTER_INGRESS_ADDRESS}" ]] && echo "environment variable 'CLUSTER_INGRESS_ADDRESS' missing" >&2 && exit 1
[[ -z "${ENV_NAME}" ]] && echo "environment variable 'ENV_NAME' missing" >&2 && exit 1
[[ -z "${LETSENCRYPT_ACCOUNT_EMAIL}" ]] && echo "environment variable 'LETSENCRYPT_ACCOUNT_EMAIL' missing" >&2 && exit 1
[[ -z "${LETSENCRYPT_URL}" ]] && echo "environment variable 'LETSENCRYPT_URL' missing" >&2 && exit 1
[[ -z "${KUBEWATCH_SLACK_TOKEN}" ]] && echo "environment variable 'KUBEWATCH_SLACK_TOKEN' missing" >&2 && exit 1
[[ -z "${WHITELISTED_IP_CIDRS}" ]] && echo "environment variable 'WHITELISTED_IP_CIDRS' missing" >&2 && exit 1

# Configure bash to exit on error
set -eu -o pipefail

# Apply infrastructure & administration permissions
kubectl apply -f ./infrastructure-administrators.yaml
kubectl apply -f ./infrastructure-storage.yaml

# Deploy cert-manager for integrating Let's Encrypt
kubectl apply \
    -f "https://raw.githubusercontent.com/jetstack/cert-manager/v0.6.2/deploy/manifests/00-crds.yaml" \
    -f "https://raw.githubusercontent.com/jetstack/cert-manager/v0.6.2/deploy/manifests/01-namespace.yaml"
kubectl apply --validate=false -f "https://raw.githubusercontent.com/jetstack/cert-manager/v0.6.2/deploy/manifests/cert-manager.yaml"
kubectl wait --timeout=5m --namespace=cert-manager --for=condition=Available deploy/cert-manager deploy/cert-manager-webhook
cat ./cert-manager-issuer.yaml | envsubst | kubectl apply -f -

# Collect metrics from cluster objects
kubectl apply -f ./monitoring-kube-state-metrics.yaml

# Export node metrics
kubectl apply -f ./monitoring-node-exporter.yaml

# Setup Prometheus
cat ./monitoring-prometheus.yaml | envsubst | kubectl apply -f -
kubectl create configmap server --namespace=prometheus --from-file=prometheus.yml=monitoring-prometheus-config.yaml --dry-run=true --output=yaml | kubectl apply -f -
kubectl create configmap adapter --namespace=prometheus --from-file=adapter.yml=monitoring-prometheus-adapter-config.yaml --dry-run=true --output=yaml | kubectl apply -f -
kubectl wait --timeout=5m --namespace=prometheus --for=condition=Available deploy/server deploy/adapter deploy/pushgateway

# Setup Traefik
cat ./traefik.yaml | envsubst | kubectl apply -f -
kubectl create configmap config --namespace=traefik --from-file=traefik.toml=traefik-config.toml --dry-run=true --output=yaml | kubectl apply -f -
kubectl wait --timeout=5m --namespace=traefik --for=condition=Available deploy/traefik
