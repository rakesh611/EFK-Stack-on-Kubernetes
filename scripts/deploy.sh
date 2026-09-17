#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Creating namespace..."
kubectl apply -f namespace.yaml

echo "Deploying Elasticsearch..."
kubectl apply -f elasticsearch/storage.yaml
kubectl apply -f elasticsearch/service.yaml
kubectl apply -f elasticsearch/statefulset.yaml

echo "Waiting for Elasticsearch..."
kubectl wait --for=condition=ready pod/elasticsearch-0 -n logging --timeout=300s

echo "Deploying Kibana..."
kubectl apply -f kibana/configmap.yaml
kubectl apply -f kibana/deployment.yaml
kubectl apply -f kibana/service.yaml

echo "Deploying Fluent Bit..."
kubectl apply -f fluent-bit/serviceaccount.yaml
kubectl apply -f fluent-bit/rbac.yaml
kubectl apply -f fluent-bit/configmap.yaml
kubectl apply -f fluent-bit/daemonset.yaml

echo "Deploying test application..."
kubectl apply -f test-app/log-generator.yaml

echo "Deployment submitted."
kubectl get pods -n logging -o wide
kubectl get pods
