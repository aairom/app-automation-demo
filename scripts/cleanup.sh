#!/bin/bash

# cleanup.sh - Complete cleanup script for Member Management Application
# This script removes all Docker resources (containers, images, volumes, networks)
# related to the application

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info "Starting cleanup of Member Management Application..."
echo ""

# Stop all running containers related to the application
print_info "Stopping running containers..."
if docker ps -q --filter "name=member-management" | grep -q .; then
    docker ps -q --filter "name=member-management" | xargs docker stop
    print_success "Stopped running containers"
else
    print_warning "No running containers found"
fi
echo ""

# Remove all containers (running and stopped)
print_info "Removing all containers..."
if docker ps -aq --filter "name=member-management" | grep -q .; then
    docker ps -aq --filter "name=member-management" | xargs docker rm -f
    print_success "Removed containers"
else
    print_warning "No containers found"
fi

# Also remove containers from docker-compose
if docker ps -aq --filter "label=com.docker.compose.project=member-management" | grep -q .; then
    docker ps -aq --filter "label=com.docker.compose.project=member-management" | xargs docker rm -f
    print_success "Removed docker-compose containers"
fi
echo ""

# Remove all images related to the application
print_info "Removing Docker images..."
IMAGES_REMOVED=0

# Remove images by name pattern
for image in $(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "member-management|vault|prometheus|grafana|otel"); do
    if docker rmi -f "$image" 2>/dev/null; then
        print_success "Removed image: $image"
        ((IMAGES_REMOVED++))
    fi
done

# Remove images by label
if docker images -q --filter "label=app=member-management" | grep -q .; then
    docker images -q --filter "label=app=member-management" | xargs docker rmi -f
    print_success "Removed labeled images"
    ((IMAGES_REMOVED++))
fi

if [ $IMAGES_REMOVED -eq 0 ]; then
    print_warning "No images found to remove"
else
    print_success "Removed $IMAGES_REMOVED image(s)"
fi
echo ""

# Remove all volumes
print_info "Removing Docker volumes..."
if docker volume ls -q --filter "name=member-management" | grep -q .; then
    docker volume ls -q --filter "name=member-management" | xargs docker volume rm -f
    print_success "Removed volumes"
else
    print_warning "No volumes found"
fi
echo ""

# Remove all networks
print_info "Removing Docker networks..."
if docker network ls -q --filter "name=member-management" | grep -q .; then
    docker network ls -q --filter "name=member-management" | xargs docker network rm
    print_success "Removed networks"
else
    print_warning "No networks found"
fi
echo ""

# Clean up dangling images and build cache
print_info "Cleaning up dangling images and build cache..."
docker image prune -f > /dev/null 2>&1
docker builder prune -f > /dev/null 2>&1
print_success "Cleaned up dangling resources"
echo ""

# Remove local data directories (optional - commented out for safety)
# Uncomment these lines if you want to remove local data as well
# print_info "Removing local data directories..."
# rm -rf data/
# rm -rf logs/
# print_success "Removed local data directories"
# echo ""

# Display remaining Docker resources
print_info "Remaining Docker resources:"
echo ""
echo "Containers:"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | head -n 10
echo ""
echo "Images:"
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | head -n 10
echo ""
echo "Volumes:"
docker volume ls --format "table {{.Name}}\t{{.Driver}}" | head -n 10
echo ""
echo "Networks:"
docker network ls --format "table {{.Name}}\t{{.Driver}}" | head -n 10
echo ""

print_success "Cleanup completed successfully!"
print_info "All Docker resources related to Member Management Application have been removed."

# Made with Bob
