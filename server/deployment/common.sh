#!/bin/bash

# ======================
# Load Environment Variables
# ======================
load_env() {
    local env_file
    env_file="$(dirname "${BASH_SOURCE[0]}")/.env"
    
    if [ ! -f "${env_file}" ]; then
        echo "Error: .env file not found at ${env_file}"
        exit 1
    fi
    
    # Load variables from .env file
    set -a
    source "${env_file}"
    set +a
    
    # Validate required variables
    local required_vars=(
        "REMOTE_USER"
        "REMOTE_HOST"
        "REMOTE_DIR"
        "REPO_URL"
        "SSH_KEY"
        "DB_NAME"
        "DB_USER"
        "DB_PASSWORD"
        "DB_PORT"
        "WEB_CONTAINER_NAME"
        "DB_CONTAINER_NAME"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo "Error: Required variable ${var} is not set in ${env_file}"
            exit 1
        fi
    done
}

# ======================
# Common Configuration
# ======================

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'  # No Color

# Initialize logging
setup_logging() {
    # Check if we're on the remote server
    if [[ "$(hostname)" == "${REMOTE_HOST}" ]]; then
        # On remote server, use the deployment directory
        LOG_DIR="${REMOTE_DIR}/server/deployment/logs"
    else
        # Locally, use the script's directory
        LOG_DIR="$(dirname "${BASH_SOURCE[0]}")/logs"
    fi
    
    # Set log file path
    LOG_FILE="${LOG_DIR}/mnist_deploy.log"
    
    # Create log directory if it doesn't exist
    mkdir -p "${LOG_DIR}" 2>/dev/null || {
        echo "Warning: Could not create log directory at ${LOG_DIR}"
        # If we can't create the log directory, log only to console
        LOG_TO_FILE=false
        return
    }
    
    # Check if we can write to the log file
    touch "${LOG_FILE}" 2>/dev/null || {
        echo "Warning: Cannot write to log file at ${LOG_FILE}"
        # If we can't write to the log file, log only to console
        LOG_TO_FILE=false
        return
    }
    
    LOG_TO_FILE=true
}

# Load environment variables first
load_env

# Setup logging
setup_logging

# ======================
# Common Functions
# ======================
log() { 
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[${timestamp}] $1"
    echo "${message}"
    if [[ "${LOG_TO_FILE}" == "true" ]]; then
        echo "${message}" >> "${LOG_FILE}"
    fi
}

log_info() { 
    local message="${YELLOW}[INFO] $1${NC}"
    echo -e "${message}"
    if [[ "${LOG_TO_FILE}" == "true" ]]; then
        # Strip color codes for file logging
        echo "[INFO] $1" >> "${LOG_FILE}"
    fi
}

log_success() { 
    local message="${GREEN}[SUCCESS] $1${NC}"
    echo -e "${message}"
    if [[ "${LOG_TO_FILE}" == "true" ]]; then
        # Strip color codes for file logging
        echo "[SUCCESS] $1" >> "${LOG_FILE}"
    fi
}

log_error() { 
    local message="${RED}[ERROR] $1${NC}"
    echo -e "${message}"
    if [[ "${LOG_TO_FILE}" == "true" ]]; then
        # Strip color codes for file logging
        echo "[ERROR] $1" >> "${LOG_FILE}"
    fi
}

# Check if running on remote server
is_remote() {
    [[ "$(hostname)" == "${REMOTE_HOST}" ]]
}

# Ensure we're in the project directory
ensure_project_dir() {
    if is_remote; then
        cd "${REMOTE_DIR}" || exit 1
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Wait for a condition with timeout
wait_for() {
    local timeout=$1
    local condition=$2
    local message=$3
    local interval=${4:-2}
    
    log "Waiting for ${message}..."
    local start_time=$(date +%s)
    while ! eval "${condition}"; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        if [ ${elapsed} -ge ${timeout} ]; then
            log_error "Timeout waiting for ${message}"
            return 1
        fi
        echo -n "."
        sleep "${interval}"
    done
    echo ""
    log "${message} is ready"
    return 0
} 