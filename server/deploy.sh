#!/bin/bash

# ================================================================================
# DEPLOYMENT SCRIPT
# ================================================================================
# This script deploys the application to the remote server
# 
# Usage:
#   ./server/deploy.sh
#
# Description:
#   This script will:
#   1. Connect to the remote server
#   2. Clone/update the application repository
#   3. Deploy Docker containers
#   4. Set up automatic database health checks
# ================================================================================

# Fail on any error
set -e

# Remote server settings
REMOTE_USER="root"
REMOTE_HOST="37.27.197.79"  # Hetzner server IP
REMOTE_DIR="/root/mnist-digit-recognizer"
REPO_URL="https://github.com/nomad-dormouse/mnist-digit-recognizer.git"
SSH_KEY="${HOME}/.ssh/hetzner_key"

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'  # No Color

# Helper functions
log_info() { echo -e "${YELLOW}$1${NC}"; }
log_success() { echo -e "${GREEN}$1${NC}"; }
log_error() { echo -e "${RED}$1${NC}"; }

# Check prerequisites
if [ ! -f "${SSH_KEY}" ]; then
  log_error "Error: SSH key not found at ${SSH_KEY}"
  log_error "Please ensure your SSH key is correctly set up."
  exit 1
fi

# Start deployment
log_info "Deploying MNIST Digit Recognizer to ${REMOTE_HOST}..."

# Export variables for SSH session
export REMOTE_DIR REPO_URL

# SSH into the remote server and perform deployment
ssh -i ${SSH_KEY} ${REMOTE_USER}@${REMOTE_HOST} << EOF
    # Exit on error
    set -e
    
    # Free up disk space
    echo "Cleaning up disk space..."
    docker system prune -af
    apt-get clean
    journalctl --vacuum-time=1d
    
    # Clone or update repository
    if [ -d "${REMOTE_DIR}" ]; then
        echo "Updating existing repository..."
        cd ${REMOTE_DIR}
        git pull
    else
        echo "Cloning repository..."
        mkdir -p "${REMOTE_DIR}"
        git clone ${REPO_URL} ${REMOTE_DIR}
        cd ${REMOTE_DIR}
    fi

    # Set up environment and ensure dependencies
    mkdir -p model/saved_models
    for cmd in docker docker-compose; do
        if ! command -v \$cmd &> /dev/null; then
            echo "\$cmd not found! Please install \$cmd first."
            exit 1
        fi
    done

    # Prepare containers
    echo "Preparing Docker environment..."
    docker-compose down || true
    
    # Stop any related containers
    docker ps -a | grep mnist-digit-recognizer | awk '{print \$1}' | xargs docker stop 2>/dev/null || true
    docker ps -a | grep mnist-digit-recognizer | awk '{print \$1}' | xargs docker rm -f 2>/dev/null || true
    
    # Check database volume
    echo "Checking database volume status..."
    if docker volume ls | grep -q mnist-digit-recognizer_postgres_data; then
        echo "Existing database volume found - preserving data"
    else
        echo "No existing database volume found, a new one will be created"
    fi
    
    # Build and start containers
    echo "Building and starting containers..."
    docker-compose build --no-cache
    docker-compose up -d
    
    # Verify deployment
    docker-compose ps
    
    # Set up database backup directory
    mkdir -p /root/db_backups
    
    # Wait for database to initialize
    echo "Waiting for database to initialize..."
    for i in {1..30}; do
        if docker exec \$(docker ps | grep postgres | awk '{print \$1}') pg_isready -U postgres; then
            echo "Database is ready!"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    # Initialize database if needed
    DB_CONTAINER=\$(docker ps | grep -E 'postgres|db' | awk '{print \$1}')
    if [ -n "\${DB_CONTAINER}" ]; then
        if ! docker exec \${DB_CONTAINER} psql -U postgres -lqt | grep -qw "mnist_db"; then
            echo "Creating 'mnist_db' database..."
            docker exec \${DB_CONTAINER} psql -U postgres -c "CREATE DATABASE mnist_db;"
        fi
        
        echo "Initializing database schema..."
        docker exec -i \${DB_CONTAINER} psql -U postgres -d mnist_db < database/init.sql
    else
        echo "ERROR: Database container not found!"
        exit 1
    fi
    
    # Create database check script for hourly monitoring
    echo "Setting up database monitoring..."
    cat > /usr/local/bin/check_mnist_db << 'EOLSCRIPT'
#!/bin/bash

# Log function
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/mnist_db_check.log; }

# Backup database if it has records
backup_database() {
  local DB_CONTAINER="$1"
  local BACKUP_DIR="/root/db_backups"
  local BACKUP_FILE="${BACKUP_DIR}/mnist_db_$(date '+%Y%m%d_%H%M%S').sql"
  
  mkdir -p "${BACKUP_DIR}"
  log "Creating backup to ${BACKUP_FILE}"
  docker exec "${DB_CONTAINER}" pg_dump -U postgres mnist_db > "${BACKUP_FILE}"
  
  # Keep only the last 7 backups
  ls -t "${BACKUP_DIR}"/mnist_db_*.sql | tail -n +8 | xargs rm -f 2>/dev/null || true
}

# Restore from latest backup
restore_latest_backup() {
  local DB_CONTAINER="$1"
  local LATEST_BACKUP=$(ls -t /root/db_backups/mnist_db_*.sql 2>/dev/null | head -n 1)
  
  if [ -n "${LATEST_BACKUP}" ]; then
    log "Restoring from backup: ${LATEST_BACKUP}"
    docker exec -i "${DB_CONTAINER}" psql -U postgres -d mnist_db < "${LATEST_BACKUP}"
    return 0
  else
    log "No backup files found"
    return 1
  fi
}

log "Starting database check"
cd /root/mnist-digit-recognizer

# Verify Docker is running
if ! docker info > /dev/null 2>&1; then
  log "Docker is not running. Exiting."
  exit 1
fi

# Ensure database container is running
DB_CONTAINER=$(docker ps | grep -E 'postgres|db' | grep mnist-digit-recognizer | awk '{print $1}')
if [ -z "${DB_CONTAINER}" ]; then
  log "Database container not running. Starting containers..."
  docker-compose up -d
  sleep 10
  DB_CONTAINER=$(docker ps | grep -E 'postgres|db' | grep mnist-digit-recognizer | awk '{print $1}')
  if [ -z "${DB_CONTAINER}" ]; then
    log "Failed to start database container. Exiting."
    exit 1
  fi
fi

# Backup existing data if any
if docker exec "${DB_CONTAINER}" psql -U postgres -lqt | grep -qw "mnist_db"; then
  if docker exec "${DB_CONTAINER}" psql -U postgres -d mnist_db -c "\dt predictions" | grep -q "predictions"; then
    ROW_COUNT=$(docker exec "${DB_CONTAINER}" psql -U postgres -d mnist_db -t -c "SELECT COUNT(*) FROM predictions;" | tr -d '[:space:]')
    if [ "${ROW_COUNT}" -gt 0 ]; then
      log "Found ${ROW_COUNT} records - creating backup"
      backup_database "${DB_CONTAINER}"
    fi
  fi
fi

# Verify/create database and tables
if ! docker exec "${DB_CONTAINER}" psql -U postgres -lqt | grep -qw "mnist_db"; then
  log "Creating mnist_db database..."
  docker exec "${DB_CONTAINER}" psql -U postgres -c "CREATE DATABASE mnist_db;"
  log "Initializing schema..."
  docker exec -i "${DB_CONTAINER}" psql -U postgres -d mnist_db < /root/mnist-digit-recognizer/database/init.sql
  restore_latest_backup "${DB_CONTAINER}"
elif ! docker exec "${DB_CONTAINER}" psql -U postgres -d mnist_db -c "\dt predictions" | grep -q "predictions"; then
  log "Creating predictions table..."
  docker exec -i "${DB_CONTAINER}" psql -U postgres -d mnist_db < /root/mnist-digit-recognizer/database/init.sql
  restore_latest_backup "${DB_CONTAINER}"
fi

# Verify web container connection
WEB_CONTAINER=$(docker ps | grep -E 'web' | grep mnist-digit-recognizer | awk '{print $1}')
if [ -n "${WEB_CONTAINER}" ]; then
  log "Testing database connection from web container..."
  if ! docker exec "${WEB_CONTAINER}" python -c "import psycopg2; conn = psycopg2.connect(host='db', port=5432, dbname='mnist_db', user='postgres', password='postgres'); print('Connection successful'); conn.close()" | grep -q "Connection successful"; then
    log "Connection failed. Restarting web container..."
    docker restart "${WEB_CONTAINER}"
  fi
else
  log "Starting web container..."
  docker-compose up -d
fi

log "Database check completed"
EOLSCRIPT

    # Make the script executable
    chmod +x /usr/local/bin/check_mnist_db

    # Set up systemd service and timer
    echo "Setting up auto-start and scheduled checks..."
    
    # App auto-start service
    cat > /etc/systemd/system/mnist-app.service << EOL
[Unit]
Description=MNIST Digit Recognizer
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${REMOTE_DIR}
ExecStart=docker-compose up -d
ExecStop=docker-compose down
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

    # Run check hourly and at boot
    cat > /etc/systemd/system/mnist-db-check.timer << EOL
[Unit]
Description=Run MNIST Database Check regularly

[Timer]
OnBootSec=1min
OnUnitActiveSec=1h

[Install]
WantedBy=timers.target
EOL

    # Enable and start services
    systemctl daemon-reload
    systemctl enable mnist-app.service
    systemctl enable mnist-db-check.timer
    systemctl start mnist-db-check.timer
    
    # Run initial check
    /usr/local/bin/check_mnist_db
    
    echo "Application deployed successfully at http://${REMOTE_HOST}:8501"
EOF

# Check deployment result
if [ $? -eq 0 ]; then
    log_success "Deployment completed successfully!"
    log_info "You can access the application at: http://${REMOTE_HOST}:8501"
else
    log_error "Deployment failed! Please check the error messages above."
    exit 1
fi 