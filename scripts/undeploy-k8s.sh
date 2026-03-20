#!/bin/bash

# Member Management Application - Kubernetes Undeployment Script
# This script removes the application from the Minikube cluster

set -e

echo "=========================================="
echo "Undeploying from Kubernetes (Minikube)"
echo "=========================================="

# Navigate to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed."
    exit 1
fi

# Delete Kubernetes resources
echo ""
echo "Deleting Kubernetes resources..."
kubectl delete -f k8s/app-deployment.yaml --ignore-not-found=true
kubectl delete -f k8s/grafana-deployment.yaml --ignore-not-found=true
kubectl delete -f k8s/prometheus-deployment.yaml --ignore-not-found=true
kubectl delete -f k8s/otel-collector-deployment.yaml --ignore-not-found=true
kubectl delete -f k8s/vault-deployment.yaml --ignore-not-found=true
kubectl delete -f k8s/pvc.yaml --ignore-not-found=true
kubectl delete -f k8s/secrets.yaml --ignore-not-found=true
kubectl delete -f k8s/configmap.yaml --ignore-not-found=true
kubectl delete -f k8s/namespace.yaml --ignore-not-found=true

echo ""
echo "=========================================="
echo "Undeployment completed successfully!"
echo "=========================================="
echo ""
echo "To deploy again: ./scripts/deploy-k8s.sh"
echo "=========================================="

# Made with Bob
