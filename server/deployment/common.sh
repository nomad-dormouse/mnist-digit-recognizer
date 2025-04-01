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

# Load environment variables
load_env

# ======================
# Common Configuration
# ======================

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'  # No Color

# Log file setup
LOG_DIR="$(dirname "${BASH_SOURCE[0]}")/logs"
LOG_FILE="${LOG_DIR}/mnist_deploy.log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# ======================
# Common Functions
# ======================
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"; }
log_info() { echo -e "${YELLOW}[INFO] $1${NC}" | tee -a "${LOG_FILE}"; }
log_success() { echo -e "${GREEN}[SUCCESS] $1${NC}" | tee -a "${LOG_FILE}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}" | tee -a "${LOG_FILE}"; }

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