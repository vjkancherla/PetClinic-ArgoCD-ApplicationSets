#!/bin/bash

# K3D Development Environment Teardown Script 
# Usage: ./infrastructure/k3d/k3d-teardown.sh [--keep-volume] [--keep-images]

set -e  # Exit on any error

# Get the project root directory (two levels up from this script)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Load environment variables safely
set -a  # Automatically export all variables
source "$PROJECT_ROOT/.env.credentials" >/dev/null 2>&1 || true
set +a

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - Load from environment variables
CLUSTER_NAME="${CLUSTER_NAME:-mycluster}"
VOLUME_NAME="${VOLUME_NAME:-k3d-data}"

# Default options
KEEP_VOLUME=false
REMOVE_IMAGES=false

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --keep-volume)
                KEEP_VOLUME=true
                shift
                ;;
            --remove-images)
                REMOVE_IMAGES=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    echo "K3D Development Environment Teardown Script"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --keep-volume      Don't delete the k3d-data Docker volume"
    echo "  --remove-images    Remove Docker images (preserved by default)"
    echo "  -h, --help         Show this help message"
    echo
    echo "Note: Jenkins data volume is always preserved to retain configuration"
    echo
    echo "Examples:"
    echo "  $0                      # Standard teardown (keeps Jenkins data, removes k3d data)"
    echo "  $0 --keep-volume       # Keep both k3d and Jenkins data volumes"
    echo "  $0 --remove-images     # Remove images but keep Jenkins data"
}

stop_jenkins_service() {
    log_info "Stopping and removing Jenkins service"
    
    JENKINS_DIR="$PROJECT_ROOT/infrastructure/jenkins"
    if [ -f "$JENKINS_DIR/docker-compose.yml" ] || [ -f "$JENKINS_DIR/docker-compose.yaml" ]; then
        cd "$JENKINS_DIR"
        
        # Stop all services defined in docker-compose
        log_info "Stopping docker-compose services..."
        docker compose stop 2>/dev/null || true
        
        # Remove all containers defined in docker-compose
        log_info "Removing docker-compose containers..."
        docker compose rm -f 2>/dev/null || true
        
        # Clean up networks and volumes created by docker-compose
        log_info "Cleaning up docker-compose networks and volumes..."
        docker compose down --volumes --remove-orphans 2>/dev/null || true
        
        log_success "Cleaned up all docker-compose resources"
    else
        log_warning "No docker-compose file found in $JENKINS_DIR"
    fi
    
    # Additional cleanup for any containers that might exist outside docker-compose
    log_info "Checking for any remaining Jenkins containers..."
    
    # List of possible Jenkins container names
    JENKINS_CONTAINERS=("jenkins-docker" "jenkins" "infrastructure-jenkins-1" "infrastructure_jenkins_1")
    
    for container_name in "${JENKINS_CONTAINERS[@]}"; do
        if docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
            log_warning "Found orphaned container: $container_name, removing it..."
            docker stop "$container_name" 2>/dev/null || true
            docker rm -f "$container_name" 2>/dev/null || true
            log_success "Removed orphaned container: $container_name"
        fi
    done
    
    # Clean up any Jenkins-related containers by image
    log_info "Checking for containers using Jenkins images..."
    JENKINS_IMAGE_CONTAINERS=$(docker ps -a --filter "ancestor=bitnami/jenkins" --format "{{.Names}}" 2>/dev/null || true)
    if [ ! -z "$JENKINS_IMAGE_CONTAINERS" ]; then
        log_warning "Found containers using Jenkins images, removing them..."
        echo "$JENKINS_IMAGE_CONTAINERS" | xargs -r docker stop 2>/dev/null || true
        echo "$JENKINS_IMAGE_CONTAINERS" | xargs -r docker rm -f 2>/dev/null || true
        log_success "Removed containers using Jenkins images"
    fi
}

delete_k3d_cluster() {
    log_info "Deleting k3d cluster: $CLUSTER_NAME"
    
    if k3d cluster list | grep -q $CLUSTER_NAME; then
        k3d cluster delete $CLUSTER_NAME
        log_success "Deleted k3d cluster: $CLUSTER_NAME"
    else
        log_warning "Cluster $CLUSTER_NAME not found"
    fi
}

cleanup_docker_volumes() {
    log_info "Managing Docker volumes"
    
    # Remove K3D data volume based on --keep-volume flag
    if [ "$KEEP_VOLUME" = true ]; then
        log_info "Keeping K3D data volume: $VOLUME_NAME (--keep-volume specified)"
    else
        if docker volume ls | grep -q "$VOLUME_NAME"; then
            docker volume rm "$VOLUME_NAME" 2>/dev/null || true
            log_success "Removed K3D data volume: $VOLUME_NAME"
        else
            log_warning "K3D data volume $VOLUME_NAME not found"
        fi
    fi
    
    # Always preserve Jenkins data volume
    if docker volume ls | grep -q "jenkins-data"; then
        log_info "Preserving Jenkins data volume: jenkins-data (retained by default)"
        log_info "This preserves Jenkins configuration, plugins, and job history"
    else
        log_info "No Jenkins data volume found"
    fi
    
    # Clean up any orphaned volumes from docker-compose (but preserve named volumes)
    log_info "Cleaning up orphaned anonymous volumes..."
    docker volume prune -f 2>/dev/null || true
    log_success "Cleaned up orphaned anonymous volumes"
}

cleanup_kubeconfig() {
    log_info "Cleaning up kubeconfig files"
    
    KUBECONFIG_FILE="$PROJECT_ROOT/k3d-kubeconfig"
    if [ -f "$KUBECONFIG_FILE" ]; then
        rm "$KUBECONFIG_FILE"
        log_success "Removed k3d-kubeconfig file from project root"
    else
        log_warning "k3d-kubeconfig file not found at project root"
    fi
}

cleanup_docker_images() {
    if [ "$REMOVE_IMAGES" = true ]; then
        log_info "Removing Docker images (--remove-images specified)"
        
        # Remove dangling images
        log_info "Removing dangling images..."
        docker image prune -f 2>/dev/null || true
        
        # Remove unused images
        log_info "Removing unused images..."
        docker image prune -a -f 2>/dev/null || true
        
        log_success "Cleaned up Docker images"
    else
        log_info "Preserving Docker images (default behavior)"
        log_info "Use --remove-images flag to remove images during teardown"
    fi
}

cleanup_docker_networks() {
    log_info "Cleaning up Docker networks"
    
    # Remove unused networks
    docker network prune -f 2>/dev/null || true
    
    # Clean up any specific networks that might be left over
    NETWORKS_TO_REMOVE=("k3d-$CLUSTER_NAME" "infrastructure_default" "infrastructure-jenkins_default")
    
    for network in "${NETWORKS_TO_REMOVE[@]}"; do
        if docker network ls --format "{{.Name}}" | grep -q "^${network}$"; then
            log_info "Removing network: $network"
            docker network rm "$network" 2>/dev/null || true
        fi
    done
    
    log_success "Cleaned up Docker networks"
}

verify_cleanup() {
    log_info "Verifying cleanup..."
    
    # Check if cluster is gone
    if k3d cluster list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
        log_error "Cluster $CLUSTER_NAME still exists"
        return 1
    fi
    
    # Check if volumes are gone (if they should be)
    if [ "$KEEP_VOLUME" = false ]; then
        if docker volume ls | grep -q "$VOLUME_NAME"; then
            log_error "K3D volume $VOLUME_NAME still exists"
            return 1
        fi
    fi
    
    # Jenkins volume should always be preserved
    if docker volume ls | grep -q "jenkins-data"; then
        log_info "Jenkins data volume preserved (expected behavior)"
    fi
    
    # Check if kubeconfig file is gone
    if [ -f "$PROJECT_ROOT/k3d-kubeconfig" ]; then
        log_error "k3d-kubeconfig file still exists at project root"
        return 1
    fi
    
    # Check for remaining Jenkins containers
    REMAINING_CONTAINERS=$(docker ps -a --filter "ancestor=bitnami/jenkins" --format "{{.Names}}" 2>/dev/null || true)
    if [ ! -z "$REMAINING_CONTAINERS" ]; then
        log_warning "Some Jenkins containers still exist: $REMAINING_CONTAINERS"
    fi
    
    log_success "Cleanup verification completed"
}

main() {
    parse_arguments "$@"
    
    log_info "Starting K3D Development Environment Teardown"
    log_info "Project Root: $PROJECT_ROOT"
    
    if [ "$KEEP_VOLUME" = true ]; then
        log_info "Volume preservation: ENABLED"
    fi
    
    if [ "$REMOVE_IMAGES" = true ]; then
        log_info "Image removal: ENABLED"
    else
        log_info "Image preservation: ENABLED (default)"
    fi
    
    echo
    
    # Confirmation prompt
    log_warning "This will tear down your entire k3d development environment!"
    log_warning "This includes: K3D cluster, Jenkins service, Docker networks"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Teardown cancelled"
        exit 0
    fi
    
    echo
    
    stop_jenkins_service
    delete_k3d_cluster
    cleanup_docker_volumes
    cleanup_kubeconfig
    cleanup_docker_images
    cleanup_docker_networks
    verify_cleanup
    
    echo
    log_success "Teardown completed successfully!"
    
    if [ "$KEEP_VOLUME" = true ]; then
        log_info "Note: Volume $VOLUME_NAME was preserved"
    fi
    
    if [ "$REMOVE_IMAGES" = true ]; then
        log_info "Note: Docker images were removed"
    else
        log_info "Note: Docker images were preserved (use --remove-images to remove)"
    fi
    
    log_info "Note: ArgoCD (if installed) was left intact"
    log_info "To reinstall: make setup"
}

# Run main function with all arguments
main "$@"