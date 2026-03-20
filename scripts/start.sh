#!/bin/bash

# Member Management Application - Start Script
# This script launches the application in detached mode using Docker Compose

set -e

echo "=========================================="
echo "Starting Member Management Application"
echo "=========================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose is not installed. Please install it and try again."
    exit 1
fi

# Navigate to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Building and starting services..."
docker-compose up -d --build

echo ""
echo "Waiting for services to be ready..."
sleep 10

# Check if services are running
if docker-compose ps | grep -q "Up"; then
    echo ""
    echo "=========================================="
    echo "Application started successfully!"
    echo "=========================================="
    echo ""
    echo "Access URLs:"
    echo "  - Application:  http://localhost:8080"
    echo "  - Vault:        http://localhost:8200"
    echo "  - Prometheus:   http://localhost:9090"
    echo "  - Grafana:      http://localhost:3000 (admin/admin)"
    echo ""
    echo "To view logs: docker-compose logs -f"
    echo "To stop: ./scripts/stop.sh"
    echo "=========================================="
else
    echo ""
    echo "Error: Some services failed to start. Check logs with: docker-compose logs"
    exit 1
fi

# Made with Bob
