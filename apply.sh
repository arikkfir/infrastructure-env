#!/usr/bin/env bash

# Verify environment is provided
[[ -z "${ALERTMANAGER_SLACK_URL}" ]] && echo "environment variable 'ALERTMANAGER_SLACK_URL' missing" >&2 && exit 1
[[ -z "${CLOUDFLARE_EMAIL}" ]] && echo "environment variable 'CLOUDFLARE_EMAIL' missing" >&2 && exit 1
[[ -z "${CLOUDFLARE_TOKEN}" ]] && echo "environment variable 'CLOUDFLARE_TOKEN' missing" >&2 && exit 1
[[ -z "${CLUSTER_INGRESS_ADDRESS}" ]] && echo "environment variable 'CLUSTER_INGRESS_ADDRESS' missing" >&2 && exit 1
[[ -z "${ENV_NAME}" ]] && echo "environment variable 'ENV_NAME' missing" >&2 && exit 1
[[ -z "${LETSENCRYPT_ACCOUNT_EMAIL}" ]] && echo "environment variable 'LETSENCRYPT_ACCOUNT_EMAIL' missing" >&2 && exit 1
[[ -z "${LETSENCRYPT_URL}" ]] && echo "environment variable 'LETSENCRYPT_URL' missing" >&2 && exit 1
[[ -z "${KUBEWATCH_SLACK_TOKEN}" ]] && echo "environment variable 'KUBEWATCH_SLACK_TOKEN' missing" >&2 && exit 1
[[ -z "${WHITELISTED_IP_CIDRS}" ]] && echo "environment variable 'WHITELISTED_IP_CIDRS' missing" >&2 && exit 1

function create_config() {
    NAMESPACE=${1}
    NAME=${2}
    shift 2
    kubectl create configmap ${NAME} --dry-run=true --output=yaml --namespace=${NAMESPACE} $@ | kubectl apply -f -
}

# init
set -eu -o pipefail
export CM_BASE="https://raw.githubusercontent.com/jetstack/cert-manager/v0.6.2/deploy/manifests"

# infrastructure
kubectl apply -f ./infrastructure-administrators.yaml
kubectl apply -f ./infrastructure-storage.yaml

# cert-manager
kubectl apply -f "${CM_BASE}/00-crds.yaml" -f "${CM_BASE}/01-namespace.yaml"
kubectl apply --validate=false -f "${CM_BASE}/cert-manager.yaml"
kubectl wait --timeout=5m --namespace=cert-manager --for=condition=Available deploy/cert-manager deploy/cert-manager-webhook
cat ./cert-manager-issuer.yaml | envsubst | kubectl apply -f -

# cluster metrics
kubectl apply -f ./monitoring-kube-state-metrics.yaml
kubectl apply -f ./monitoring-node-exporter.yaml

# Setup Prometheus
cat monitoring-prometheus-alertmanager-config-template.yml | envsubst > monitoring-prometheus-alertmanager-config.yml
cat ./monitoring-prometheus.yaml | envsubst | kubectl apply -f -
create_config prometheus server --from-file=prometheus.yml=monitoring-prometheus-config.yaml
create_config prometheus adapter --from-file=adapter.yml=monitoring-prometheus-adapter-config.yaml
create_config prometheus alertmanager --from-file=alertmanager.yml=monitoring-prometheus-alertmanager-config.yml
kubectl wait --timeout=5m --namespace=prometheus --for=condition=Available deploy/server deploy/adapter deploy/pushgateway deploy/alertmanager

# Setup Traefik
cat ./traefik.yaml | envsubst | kubectl apply -f -
kubectl wait --timeout=5m --namespace=traefik --for=condition=Available deploy/traefik
