#!/bin/bash

# Source common functions and variables
# shellcheck source=./common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ======================
# Environment Functions
# ======================

# Check all prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check SSH key
    if [ ! -f "${SSH_KEY}" ]; then
        log_error "SSH key not found at ${SSH_KEY}"
        log_error "Please ensure your SSH key is correctly set up."
        exit 1
    fi
    
    # Check required commands
    local required_commands=("docker" "docker-compose" "git" "ssh")
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "${cmd}"; then
            log_error "Required command '${cmd}' not found"
            exit 1
        fi
    done
    
    log "Prerequisites check passed"
}

# Set up the environment
setup_environment() {
    log "Setting up environment..."
    
    # Clean old logs
    if is_remote; then
        journalctl --vacuum-time=1d
    fi
    
    # Create required directories
    ensure_project_dir
    mkdir -p model/saved_models
    mkdir -p /root/db_backups
    
    # Update/clone repository
    if [ -d "${REMOTE_DIR}" ]; then
        log "Updating existing repository..."
        cd "${REMOTE_DIR}" || exit 1
        git pull
    else
        log "Cloning repository..."
        mkdir -p "${REMOTE_DIR}"
        git clone "${REPO_URL}" "${REMOTE_DIR}"
        cd "${REMOTE_DIR}" || exit 1
    fi
    
    # Verify Docker is running
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker is not running"
        exit 1
    fi
    
    log "Environment setup completed"
}

# Clean up environment
cleanup_environment() {
    log "Cleaning up environment..."
    
    # Remove old logs but keep recent ones
    if is_remote; then
        find /var/log/mnist_deploy.log -mtime +7 -delete
    fi
    
    # Clean up old backups (keep last 7)
    if [ -d "/root/db_backups" ]; then
        ls -t /root/db_backups/mnist_db_*.sql | tail -n +8 | xargs rm -f 2>/dev/null || true
    fi
    
    log "Environment cleanup completed"
} 