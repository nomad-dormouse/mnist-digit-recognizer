#!/bin/bash

# ================================================================================
# Service Management Script
# ================================================================================
# This script manages the MNIST Digit Recognizer services
# 
# Usage:
#   ./services.sh {start|stop|restart|status}
#
# Options:
#   start   - Start all services
#   stop    - Stop all services
#   restart - Restart all services
#   status  - Check the status of all services
# ================================================================================

# Source common functions and variables
# shellcheck source=./common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ======================
# Service Functions
# ======================

# Create the database check script
create_db_check_script() {
    log "Creating database check script..."
    
    cat > /usr/local/bin/check_mnist_db << 'CHECKSCRIPT'
#!/bin/bash

# Source common functions
source /root/mnist-digit-recognizer/remote/common.sh
source /root/mnist-digit-recognizer/remote/database.sh
source /root/mnist-digit-recognizer/remote/containers.sh

log "Starting database check"
ensure_project_dir

# Verify Docker is running
if ! docker info > /dev/null 2>&1; then
    log_error "Docker is not running"
    exit 1
fi

# Check container health
if ! check_containers; then
    log "Attempting to restart containers..."
    restart_containers
fi

# Check database health
if ! check_database; then
    log "Attempting to reinitialize database..."
    initialize_database
fi

# Verify database connection
if ! verify_db_connection; then
    log "Attempting to fix connection issues..."
    restart_containers
    sleep 5
    verify_db_connection
fi

log "Database check completed"
CHECKSCRIPT

    chmod +x /usr/local/bin/check_mnist_db
    log "Database check script created"
}

# Create systemd services
create_systemd_services() {
    log "Creating systemd services..."
    
    # App service
    cat > /etc/systemd/system/mnist-app.service << EOL
[Unit]
Description=MNIST Digit Recognizer
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${REMOTE_DIR}
ExecStart=docker-compose -f ${DOCKER_COMPOSE_FILE} up -d
ExecStop=docker-compose -f ${DOCKER_COMPOSE_FILE} down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOL

    # Database check service
    cat > /etc/systemd/system/mnist-db-check.service << EOL
[Unit]
Description=MNIST Database Check
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/check_mnist_db
EOL

    # Database check timer
    cat > /etc/systemd/system/mnist-db-check.timer << EOL
[Unit]
Description=Run MNIST Database Check regularly

[Timer]
OnBootSec=1min
OnUnitActiveSec=${DB_CHECK_INTERVAL}

[Install]
WantedBy=timers.target
EOL

    log "Systemd services created"
}

# Enable and start services
setup_services() {
    log "Setting up system services..."
    
    # Create scripts and services
    create_db_check_script
    create_systemd_services
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable services
    systemctl enable mnist-app.service
    systemctl enable mnist-db-check.timer
    
    # Start services
    systemctl start mnist-db-check.timer
    
    # Run initial check
    /usr/local/bin/check_mnist_db
    
    log "System services setup completed"
} 