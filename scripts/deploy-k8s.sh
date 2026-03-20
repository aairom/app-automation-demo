#!/bin/bash

# Member Management Application - Kubernetes Deployment Script
# This script deploys the application to a Minikube cluster

set -e

echo "=========================================="
echo "Deploying to Kubernetes (Minikube)"
echo "=========================================="

# Navigate to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "Error: minikube is not installed. Please install it and try again."
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed. Please install it and try again."
    exit 1
fi

# Check if Minikube is running
if ! minikube status > /dev/null 2>&1; then
    echo "Starting Minikube..."
    minikube start
fi

# Build Docker image
echo ""
echo "Building Docker image..."
docker build -t member-management-app:latest .

# Load image into Minikube
echo ""
echo "Loading image into Minikube..."
minikube image load member-management-app:latest

# Apply Kubernetes manifests
echo ""
echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/pvc.yaml
kubectl apply -f k8s/vault-deployment.yaml
kubectl apply -f k8s/otel-collector-deployment.yaml
kubectl apply -f k8s/prometheus-deployment.yaml
kubectl apply -f k8s/grafana-deployment.yaml
kubectl apply -f k8s/app-deployment.yaml

# Wait for deployments to be ready
echo ""
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/vault -n member-management
kubectl wait --for=condition=available --timeout=300s deployment/otel-collector -n member-management
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n member-management
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n member-management
kubectl wait --for=condition=available --timeout=300s deployment/member-management-app -n member-management

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

echo ""
echo "=========================================="
echo "Deployment completed successfully!"
echo "=========================================="
echo ""
echo "Access URLs:"
echo "  - Application:  http://${MINIKUBE_IP}:30080"
echo "  - Prometheus:   http://${MINIKUBE_IP}:30090"
echo "  - Grafana:      http://${MINIKUBE_IP}:30030 (admin/admin)"
echo ""
echo "To view pods: kubectl get pods -n member-management"
echo "To view logs: kubectl logs -f deployment/member-management-app -n member-management"
echo "To undeploy: ./scripts/undeploy-k8s.sh"
echo "=========================================="

# Made with Bob
