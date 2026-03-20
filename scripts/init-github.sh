#!/bin/bash

# GitHub Initialization and Push Script
# This script initializes a git repository and pushes to GitHub
# Usage: ./scripts/init-github.sh <github-repo-url> <commit-message>

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if correct number of arguments provided
if [ "$#" -ne 2 ]; then
    print_error "Usage: $0 <github-repo-url> <commit-message>"
    echo "Example: $0 https://github.com/username/repo.git \"Initial commit\""
    exit 1
fi

REPO_URL="$1"
COMMIT_MESSAGE="$2"

# Navigate to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

print_info "Project root: $PROJECT_ROOT"

# Check if git is installed
if ! command -v git &> /dev/null; then
    print_error "Git is not installed. Please install git and try again."
    exit 1
fi

# Check if .git directory already exists
if [ -d ".git" ]; then
    print_warning "Git repository already initialized."
    
    # Check if remote origin exists
    if git remote get-url origin &> /dev/null; then
        EXISTING_REMOTE=$(git remote get-url origin)
        print_warning "Remote 'origin' already exists: $EXISTING_REMOTE"
        
        # If different URL, update it
        if [ "$EXISTING_REMOTE" != "$REPO_URL" ]; then
            print_info "Updating remote URL to: $REPO_URL"
            git remote set-url origin "$REPO_URL"
        fi
    else
        print_info "Adding remote origin: $REPO_URL"
        git remote add origin "$REPO_URL"
    fi
else
    print_info "Initializing git repository..."
    git init
    
    print_info "Adding remote origin: $REPO_URL"
    git remote add origin "$REPO_URL"
fi

# Configure git to use main as default branch
print_info "Setting default branch to 'main'..."
git branch -M main

# Add all files
print_info "Adding all files to git..."
git add .

# Check if there are changes to commit
if git diff --staged --quiet; then
    print_warning "No changes to commit."
else
    print_info "Committing changes with message: \"$COMMIT_MESSAGE\""
    git commit -m "$COMMIT_MESSAGE"
fi

# Push to GitHub
print_info "Pushing to GitHub..."
if git push -u origin main 2>&1 | grep -q "rejected"; then
    print_warning "Push rejected. Attempting to pull and merge..."
    
    # Pull with rebase to avoid merge commits
    git pull --rebase origin main
    
    print_info "Retrying push..."
    git push -u origin main
else
    # First time push or successful push
    git push -u origin main 2>&1 || {
        print_error "Push failed. This might be the first push to an empty repository."
        print_info "Attempting force push for initial commit..."
        git push -u origin main --force
    }
fi

print_info "=========================================="
print_info "Successfully pushed to GitHub!"
print_info "=========================================="
print_info "Repository URL: $REPO_URL"
print_info "Branch: main"
print_info "Commit: $COMMIT_MESSAGE"
print_info "=========================================="

# Display remote info
print_info "Remote configuration:"
git remote -v

print_info ""
print_info "To view your repository, visit:"
echo "$REPO_URL" | sed 's/\.git$//'

# Made with Bob
