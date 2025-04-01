#!/bin/bash

# ================================================================================
# MNIST Digit Recognizer - Common Functions
# ================================================================================
# This script contains shared functions and variables used across deployment scripts.
# It handles logging, environment variables, and common utilities.
# ================================================================================

# Terminal color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize logging
setup_logging() {
    # Determine if we're running locally or remotely
    if [ -n "${REMOTE_DIR:-}" ]; then
        # Remote environment - use /var/log for system-wide logs
        LOG_DIR="/var/log/mnist-digit-recognizer"
    else
        # Local environment - use script's directory
        LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/logs"
    fi
    
    # Create logs directory if it doesn't exist
    if ! mkdir -p "${LOG_DIR}" 2>/dev/null; then
        # If we can't create in /var/log, try user's home directory
        if [ -n "${REMOTE_DIR:-}" ]; then
            LOG_DIR="${HOME}/.mnist-digit-recognizer/logs"
            if ! mkdir -p "${LOG_DIR}" 2>/dev/null; then
                echo "Warning: Could not create log directory at ${LOG_DIR}" >&2
                LOG_FILE="/dev/null"
            else
                LOG_FILE="${LOG_DIR}/mnist_deploy.log"
            fi
        else
            echo "Warning: Could not create log directory at ${LOG_DIR}" >&2
            LOG_FILE="/dev/null"
        fi
    else
        LOG_FILE="${LOG_DIR}/mnist_deploy.log"
    fi
}

# Load environment variables from .env file
load_env() {
    local env_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.env"
    
    if [ ! -f "${env_file}" ]; then
        echo "Error: .env file not found at ${env_file}" >&2
        exit 1
    fi
    
    # Load environment variables
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
        if [ -z "${!var:-}" ]; then
            echo "Error: Required environment variable ${var} is not set" >&2
            exit 1
        fi
    done
}

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[${timestamp}] ${level}: ${message}"
    
    # Always output to console
    case "${level}" in
        "ERROR") echo -e "${RED}${log_entry}${NC}" ;;
        "SUCCESS") echo -e "${GREEN}${log_entry}${NC}" ;;
        "WARNING") echo -e "${YELLOW}${log_entry}${NC}" ;;
        "INFO") echo -e "${BLUE}${log_entry}${NC}" ;;
        *) echo "${log_entry}" ;;
    esac
    
    # Try to write to log file if it exists
    if [ -n "${LOG_FILE:-}" ] && [ "${LOG_FILE}" != "/dev/null" ]; then
        echo "${log_entry}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

log_info() { log "INFO" "$*"; }
log_success() { log "SUCCESS" "$*"; }
log_warning() { log "WARNING" "$*"; }
log_error() { log "ERROR" "$*"; }

# Load environment variables first
load_env

# Then set up logging
setup_logging

# Log script initialization
log_info "Initializing deployment scripts..."

# ======================
# Common Configuration
# ======================

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'  # No Color

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