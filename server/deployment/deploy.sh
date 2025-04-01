#!/bin/bash

# ================================================================================
# MNIST Digit Recognizer - Main Deployment Script
# ================================================================================
# This script handles the complete deployment process for the MNIST application.
# It uses a modular approach with separate scripts for different functionalities:
#
# - common.sh: Shared functions and variables
# - environment.sh: Environment setup and prerequisites
# - database.sh: Database management and health checks
# - containers.sh: Docker container management
# - services.sh: Systemd services setup
#
# Usage: ./deploy.sh
# ================================================================================

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all required scripts
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/environment.sh"
source "${SCRIPT_DIR}/database.sh"
source "${SCRIPT_DIR}/containers.sh"
source "${SCRIPT_DIR}/services.sh"

# ======================
# Main Deployment
# ======================
main() {
    log_info "Starting deployment to ${REMOTE_HOST}..."
    
    # Check prerequisites locally
    check_prerequisites
    
    # Create remote directories and copy deployment files
    log_info "Setting up remote deployment directory..."
    ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${REMOTE_DIR}/server/deployment"
    
    log_info "Copying deployment files..."
    scp -i "${SSH_KEY}" \
        "${SCRIPT_DIR}"/{common.sh,environment.sh,database.sh,containers.sh,services.sh,.env} \
        "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/server/deployment/"
    
    # Execute remote deployment
    if ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" "$(cat << REMOTESCRIPT
        # Strict error handling
        set -euo pipefail
        
        # Export environment variables
        export REMOTE_DIR='${REMOTE_DIR}'
        export DB_NAME='${DB_NAME}'
        export DB_USER='${DB_USER}'
        export DB_PASSWORD='${DB_PASSWORD}'
        export DB_PORT='${DB_PORT}'
        export WEB_CONTAINER_NAME='${WEB_CONTAINER_NAME}'
        export DB_CONTAINER_NAME='${DB_CONTAINER_NAME}'
        
        # Create logs directory first
        mkdir -p '${REMOTE_DIR}/server/deployment/logs'
        
        # Change to deployment directory
        cd '${REMOTE_DIR}/server/deployment'
        
        # Source all required scripts
        source ./common.sh
        source ./environment.sh
        source ./database.sh
        source ./containers.sh
        source ./services.sh
        
        # Main deployment function
        deploy() {
            # Set up environment
            setup_environment
            
            # Manage containers
            manage_containers
            
            # Initialize database
            initialize_database
            
            # Verify database connection
            verify_db_connection
            
            # Set up system services
            setup_services
            
            log "Deployment completed successfully"
        }
        
        # Run deployment
        deploy
REMOTESCRIPT
)"; then
        log_success "Deployment completed successfully!"
        log_info "You can access the application at: http://${REMOTE_HOST}:8501"
    else
        log_error "Deployment failed! Please check the error messages above."
        exit 1
    fi
}

# Update existing repository
update_repository() {
    log "Updating existing repository..."
    if ! ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" "cd '${REMOTE_DIR}' && \
        if [ -n \"\$(git status --porcelain)\" ]; then \
            git stash push -m 'Auto-stash for deployment' && \
            git pull origin master && \
            git stash pop || true; \
        else \
            git pull origin master; \
        fi"; then
        log_error "Failed to update repository"
        return 1
    fi
    log_success "Repository updated successfully"
}

# Run main function
main 