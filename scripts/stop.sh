#!/bin/bash

# Member Management Application - Stop Script
# This script stops all running services

set -e

echo "=========================================="
echo "Stopping Member Management Application"
echo "=========================================="

# Navigate to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose is not installed."
    exit 1
fi

echo "Stopping services..."
docker-compose down

echo ""
echo "=========================================="
echo "Application stopped successfully!"
echo "=========================================="
echo ""
echo "To remove volumes (WARNING: This will delete all data):"
echo "  docker-compose down -v"
echo ""
echo "To start again: ./scripts/start.sh"
echo "=========================================="

# Made with Bob
