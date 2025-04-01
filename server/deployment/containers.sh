#!/bin/bash

# Source common functions and variables
# shellcheck source=./common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ======================
# Container Functions
# ======================

# Get container ID by name pattern
get_container_id() {
    local name_pattern="$1"
    docker ps -q -f "name=${name_pattern}"
}

# Check if container exists and is running
is_container_running() {
    local name_pattern="$1"
    [ -n "$(get_container_id "${name_pattern}")" ]
}

# Stop and remove container
remove_container() {
    local name_pattern="$1"
    local container_id
    container_id=$(get_container_id "${name_pattern}")
    
    if [ -n "${container_id}" ]; then
        log "Stopping container ${name_pattern}..."
        docker stop "${container_id}"
        docker rm "${container_id}"
    fi
}

# Manage containers
manage_containers() {
    log "Managing containers..."
    ensure_project_dir
    
    # Check running containers
    local db_running
    local web_running
    db_running=$(get_container_id "${DB_CONTAINER_NAME}")
    web_running=$(get_container_id "${WEB_CONTAINER_NAME}")
    
    # Check volume persistence
    if docker volume ls | grep -q "${DB_VOLUME_NAME}"; then
        log "Found existing database volume - preserving data"
    else
        log "Creating new database volume"
    fi
    
    # Backup database if running and has data
    if [ -n "${db_running}" ]; then
        if docker exec "${db_running}" psql -U "${DB_USER}" -lqt | grep -qw "${DB_NAME}"; then
            backup_database "${db_running}"
        fi
    fi
    
    # Stop web container if running
    if [ -n "${web_running}" ]; then
        remove_container "${WEB_CONTAINER_NAME}"
    fi
    
    # Start containers
    log "Starting containers..."
    if ! docker-compose -f "${DOCKER_COMPOSE_FILE}" up -d --build web; then
        log_error "Failed to start containers"
        return 1
    fi
    
    log "Containers started successfully"
    return 0
}

# Restart containers
restart_containers() {
    log "Restarting containers..."
    ensure_project_dir
    
    # Stop containers
    docker-compose -f "${DOCKER_COMPOSE_FILE}" down
    
    # Start containers
    if ! docker-compose -f "${DOCKER_COMPOSE_FILE}" up -d; then
        log_error "Failed to restart containers"
        return 1
    fi
    
    # Wait for containers to be ready
    sleep 10
    
    log "Containers restarted successfully"
    return 0
}

# Check container health
check_containers() {
    log "Checking container health..."
    ensure_project_dir
    
    local containers=("${DB_CONTAINER_NAME}" "${WEB_CONTAINER_NAME}")
    local all_healthy=true
    
    for container in "${containers[@]}"; do
        if ! is_container_running "${container}"; then
            log_error "Container ${container} is not running"
            all_healthy=false
        else
            local container_id
            container_id=$(get_container_id "${container}")
            local status
            status=$(docker inspect --format='{{.State.Status}}' "${container_id}")
            
            if [ "${status}" != "running" ]; then
                log_error "Container ${container} is in ${status} state"
                all_healthy=false
            else
                log "Container ${container} is healthy"
            fi
        fi
    done
    
    if [ "${all_healthy}" = true ]; then
        log "All containers are healthy"
        return 0
    else
        log_error "Some containers are unhealthy"
        return 1
    fi
} 