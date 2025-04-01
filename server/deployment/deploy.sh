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
# Usage: ./server/deployment/deploy.sh
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
    
    # Execute remote deployment
    if ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" "$(cat << 'REMOTESCRIPT'
        # Strict error handling
        set -euo pipefail
        
        # Source all required scripts
        cd /root/mnist-digit-recognizer/server/deployment
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

# Run main function
main 