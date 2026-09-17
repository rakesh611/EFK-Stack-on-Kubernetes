#!/usr/bin/env bash
set -euo pipefail

echo "WARNING: This deletes the logging namespace and lab logs."
read -r -p "Continue? Type DELETE: " ANSWER

if [[ "$ANSWER" != "DELETE" ]]; then
  echo "Cleanup cancelled."
  exit 0
fi

kubectl delete namespace logging --ignore-not-found
kubectl delete -f test-app/log-generator.yaml --ignore-not-found

echo "Cleanup submitted."
