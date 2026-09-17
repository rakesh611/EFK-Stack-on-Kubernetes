#!/usr/bin/env bash
set -euo pipefail

echo "=== Logging namespace ==="
kubectl get all -n logging

echo
echo "=== PVCs ==="
kubectl get pvc -n logging

echo
echo "=== Fluent Bit pods ==="
kubectl get pods -n logging -l app=fluent-bit -o wide

echo
echo "=== Elasticsearch health through temporary port-forward ==="
kubectl port-forward -n logging svc/elasticsearch 9200:9200 >/tmp/efk-es-port-forward.log 2>&1 &
PF_PID=$!
trap 'kill "$PF_PID" 2>/dev/null || true' EXIT
sleep 5

curl -fsS http://127.0.0.1:9200/_cluster/health?pretty
echo
curl -fsS http://127.0.0.1:9200/_cat/indices?v
echo
echo "Verification complete."
