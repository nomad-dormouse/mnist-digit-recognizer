#!/bin/bash

# Source common functions and variables
# shellcheck source=./common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ======================
# Database Functions
# ======================

# Create a backup of the database
backup_database() {
    local db_container="$1"
    log "Creating database backup..."
    
    ensure_project_dir
    mkdir -p "${BACKUP_DIR}"
    
    local backup_file="${BACKUP_DIR}/${DB_NAME}_$(date '+%Y%m%d_%H%M%S').sql"
    if docker exec "${db_container}" pg_dump -U "${DB_USER}" "${DB_NAME}" > "${backup_file}"; then
        log "Backup created: ${backup_file}"
        
        # Keep only last N backups
        ls -t "${BACKUP_DIR}"/${DB_NAME}_*.sql | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f 2>/dev/null || true
        return 0
    else
        log_error "Failed to create backup"
        return 1
    fi
}

# Restore database from latest backup
restore_database() {
    local db_container="$1"
    log "Attempting to restore database..."
    
    local latest_backup
    latest_backup=$(ls -t "${BACKUP_DIR}"/${DB_NAME}_*.sql 2>/dev/null | head -n 1)
    
    if [ -n "${latest_backup}" ]; then
        log "Restoring from backup: ${latest_backup}"
        if docker exec -i "${db_container}" psql -U "${DB_USER}" -d "${DB_NAME}" < "${latest_backup}"; then
            log "Database restored successfully"
            return 0
        else
            log_error "Failed to restore database"
            return 1
        fi
    else
        log "No backup files found"
        return 1
    fi
}

# Initialize the database
initialize_database() {
    log "Initializing database..."
    ensure_project_dir
    
    # Wait for database to be ready
    local db_container
    db_container=$(docker ps -q -f name="${DB_CONTAINER_NAME}")
    
    if [ -z "${db_container}" ]; then
        log_error "Database container not found"
        return 1
    fi
    
    # Wait for PostgreSQL to be ready
    if ! wait_for 60 "docker exec ${db_container} pg_isready -U ${DB_USER}" "PostgreSQL"; then
        log_error "Database failed to become ready"
        return 1
    fi
    
    # Create database if it doesn't exist
    if ! docker exec "${db_container}" psql -U "${DB_USER}" -lqt | grep -qw "${DB_NAME}"; then
        log "Creating ${DB_NAME} database..."
        if ! docker exec "${db_container}" psql -U "${DB_USER}" -c "CREATE DATABASE ${DB_NAME};"; then
            log_error "Failed to create database"
            return 1
        fi
        
        log "Initializing schema..."
        if ! docker exec -i "${db_container}" psql -U "${DB_USER}" -d "${DB_NAME}" < database/init.sql; then
            log_error "Failed to initialize schema"
            return 1
        fi
        
        # Attempt to restore from backup
        restore_database "${db_container}"
    fi
    
    log "Database initialization completed"
    return 0
}

# Check database health
check_database() {
    log "Checking database health..."
    ensure_project_dir
    
    local db_container
    db_container=$(docker ps -q -f name="${DB_CONTAINER_NAME}")
    
    if [ -z "${db_container}" ]; then
        log_error "Database container not running"
        return 1
    fi
    
    # Check if database exists
    if ! docker exec "${db_container}" psql -U "${DB_USER}" -lqt | grep -qw "${DB_NAME}"; then
        log_error "Database '${DB_NAME}' does not exist"
        return 1
    fi
    
    # Check if predictions table exists
    if ! docker exec "${db_container}" psql -U "${DB_USER}" -d "${DB_NAME}" -c "\dt predictions" | grep -q "predictions"; then
        log_error "Table 'predictions' does not exist"
        return 1
    fi
    
    # Check row count
    local row_count
    row_count=$(docker exec "${db_container}" psql -U postgres -d mnist_db -t -c "SELECT COUNT(*) FROM predictions;" | tr -d '[:space:]')
    log "Found ${row_count} records in predictions table"
    
    # Create backup if there are records
    if [ "${row_count}" -gt 0 ]; then
        backup_database "${db_container}"
    fi
    
    log "Database health check completed"
    return 0
}

# Verify database connection from web container
verify_db_connection() {
    log "Verifying database connection..."
    
    local web_container
    web_container=$(docker ps -q -f name=mnist-digit-recognizer-web)
    
    if [ -z "${web_container}" ]; then
        log_error "Web container not running"
        return 1
    fi
    
    local max_retries=5
    for i in $(seq 1 ${max_retries}); do
        log "Connection attempt ${i}/${max_retries}..."
        if docker exec "${web_container}" python -c "
import psycopg2
try:
    conn = psycopg2.connect(
        host='db',
        port=5432,
        dbname='mnist_db',
        user='postgres',
        password='postgres'
    )
    print('Connection successful')
    conn.close()
except Exception as e:
    print(f'Connection failed: {e}')
    exit(1)
" 2>&1; then
            log "Database connection verified"
            return 0
        else
            if [ "${i}" -eq "${max_retries}" ]; then
                log_error "Failed to establish database connection after ${max_retries} attempts"
                return 1
            fi
            log "Retrying in 5 seconds..."
            sleep 5
        fi
    done
    
    return 1
} 