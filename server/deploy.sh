#!/bin/bash

# ================================================================================
# DEPLOYMENT SCRIPT
# ================================================================================
# This script deploys the application to the remote server
# 
# Usage:
#   ./server/deploy.sh
#
# Requirements:
#   - SSH access to the remote server (Hetzner)
#   - SSH key at ~/.ssh/hetzner_key
#   - Git and Docker installed on the remote server
#
# Description:
#   This script will:
#   1. Connect to the remote server
#   2. Clone/update the application repository
#   3. Train the model if needed
#   4. Build and deploy Docker containers
#   5. Configure the application to start on boot
# ================================================================================

# ================================================================================
# CONFIGURATION
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
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# ================================================================================
# FUNCTIONS
# ================================================================================
function log_info() {
  echo -e "${YELLOW}$1${NC}"
}

function log_success() {
  echo -e "${GREEN}$1${NC}"
}

function log_error() {
  echo -e "${RED}$1${NC}"
}

function check_prerequisites() {
  if [ ! -f "${SSH_KEY}" ]; then
    log_error "Error: SSH key not found at ${SSH_KEY}"
    log_error "Please ensure your SSH key is correctly set up."
    exit 1
  fi
}

# ================================================================================
# MAIN EXECUTION
# ================================================================================
# Check prerequisites
check_prerequisites

# Start deployment
log_info "Deploying MNIST Digit Recognizer to ${REMOTE_HOST}..."

# SSH into the remote server and perform deployment
ssh -i ${SSH_KEY} ${REMOTE_USER}@${REMOTE_HOST} << EOF
    # Exit on error
    set -e
    
    # Free up disk space
    echo "Cleaning up disk space..."
    docker system prune -af --volumes
    apt-get clean
    journalctl --vacuum-time=1d
    
    # Show available space
    echo "Available disk space:"
    df -h /
    
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

    # Set up environment
    echo "Setting up environment..."
    mkdir -p model/saved_models

    # Check dependencies
    echo "Checking dependencies..."
    for cmd in docker docker-compose; do
        if ! command -v \$cmd &> /dev/null; then
            echo "\$cmd not found! Please install \$cmd first."
            exit 1
        fi
    done

    # Train model if needed
    if [ ! -f "model/saved_models/mnist_model.pth" ]; then
        echo "Training the model..."
        docker run --rm -v \$(pwd):/app -w /app python:3.9-slim bash -c \
            "pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu torchvision numpy && python model/train.py"
    else
        echo "Model already exists, skipping training."
    fi

    # Prepare containers
    echo "Preparing Docker environment..."
    docker-compose down || true
    
    # Make sure all related containers are stopped
    echo "Stopping any related containers..."
    docker ps -a | grep mnist-digit-recognizer | awk '{print $1}' | xargs docker stop 2>/dev/null || true
    docker ps -a | grep mnist-digit-recognizer | awk '{print $1}' | xargs docker rm -f 2>/dev/null || true
    
    # Clean up volumes for fresh start
    echo "Removing old database volume to ensure clean state..."
    docker volume rm -f mnist-digit-recognizer_postgres_data || true
    
    # Ensure CPU-only PyTorch to save space
    if [ -f "Dockerfile" ]; then
        echo "Configuring for CPU-only PyTorch..."
        sed -i 's/torch/torch --index-url https:\/\/download.pytorch.org\/whl\/cpu\//g' Dockerfile
        sed -i '/nvidia-cudnn-cu12/d' Dockerfile
    fi
    
    # Build and start containers
    echo "Building and starting containers..."
    docker-compose build --no-cache
    docker-compose up -d
    
    # Verify deployment
    echo "Verifying deployment..."
    docker-compose ps
    
    # Wait for database to be ready
    echo "Waiting for database to initialize..."
    for i in {1..30}; do
        if docker exec \$(docker ps | grep postgres | awk '{print \$1}') pg_isready -U postgres; then
            echo "Database is ready!"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    # Verify database setup
    echo "Verifying database setup..."
    DB_CONTAINER=\$(docker ps | grep -E 'postgres|db' | awk '{print \$1}')
    
    if [ -n "\${DB_CONTAINER}" ]; then
        # Check if database exists
        if ! docker exec \${DB_CONTAINER} psql -U postgres -lqt | cut -d \| -f 1 | grep -qw "mnist_db"; then
            echo "Database 'mnist_db' not found. Creating it now..."
            docker exec \${DB_CONTAINER} psql -U postgres -c "CREATE DATABASE mnist_db;"
        else
            echo "Database 'mnist_db' exists."
        fi
        
        # Import init.sql into the database
        echo "Initializing database schema..."
        docker exec -i \${DB_CONTAINER} psql -U postgres -d mnist_db < database/init.sql
        
        # Verify table setup
        echo "Verifying table setup..."
        if docker exec \${DB_CONTAINER} psql -U postgres -d mnist_db -c "\\dt predictions" | grep -q "predictions"; then
            echo "Table 'predictions' exists and is ready."
        else
            echo "WARNING: Table 'predictions' was not created properly. Check your init.sql file."
        fi
    else
        echo "ERROR: Database container not found! Check your docker-compose configuration."
    fi
    
    # Configure auto-start
    echo "Setting up auto-start service..."
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

    # Create a script to check and repair the database
    echo "Creating database check script..."
    cat > ${REMOTE_DIR}/server/db_check.sh << EOL
#!/bin/bash

# Log function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] \$1" | tee -a /var/log/mnist_db_check.log
}

log "Starting database check"

# Make sure we're in the right directory
cd ${REMOTE_DIR}

# Check if docker is running
if ! docker info > /dev/null 2>&1; then
  log "Docker is not running. Exiting."
  exit 1
fi

# Check if the database container is running
DB_CONTAINER=\$(docker ps | grep -E 'postgres|db' | grep mnist-digit-recognizer | awk '{print \$1}')

if [ -z "\$DB_CONTAINER" ]; then
  log "Database container not running. Starting containers..."
  docker-compose up -d
  
  # Wait for database to start
  sleep 10
  DB_CONTAINER=\$(docker ps | grep -E 'postgres|db' | grep mnist-digit-recognizer | awk '{print \$1}')
  
  if [ -z "\$DB_CONTAINER" ]; then
    log "Failed to start database container. Exiting."
    exit 1
  fi
fi

log "Database container is running: \$DB_CONTAINER"

# Check if the mnist_db database exists
if ! docker exec \$DB_CONTAINER psql -U postgres -lqt | cut -d \| -f 1 | grep -qw "mnist_db"; then
  log "mnist_db database not found. Creating it..."
  docker exec \$DB_CONTAINER psql -U postgres -c "CREATE DATABASE mnist_db;"
  
  # Apply init.sql to the new database
  log "Initializing database schema..."
  docker exec -i \$DB_CONTAINER psql -U postgres -d mnist_db < ${REMOTE_DIR}/database/init.sql
  
  log "Database initialization complete"
else
  log "mnist_db database already exists"
  
  # Verify the predictions table exists
  if ! docker exec \$DB_CONTAINER psql -U postgres -d mnist_db -c "\\dt predictions" | grep -q "predictions"; then
    log "predictions table not found. Creating it..."
    docker exec -i \$DB_CONTAINER psql -U postgres -d mnist_db < ${REMOTE_DIR}/database/init.sql
    log "Table creation complete"
  else
    log "predictions table already exists"
  fi
fi

# Verify the web container can connect to the database
WEB_CONTAINER=\$(docker ps | grep -E 'web' | grep mnist-digit-recognizer | awk '{print \$1}')
if [ -n "\$WEB_CONTAINER" ]; then
  log "Testing database connection from web container..."
  if docker exec \$WEB_CONTAINER python -c "import psycopg2; psycopg2.connect(host='db', port=5432, dbname='mnist_db', user='postgres', password='postgres')" > /dev/null 2>&1; then
    log "Connection test successful"
  else
    log "Connection test failed. Restarting web container..."
    docker restart \$WEB_CONTAINER
    log "Web container restarted"
  fi
else
  log "Web container not running. Starting containers..."
  docker-compose up -d
  log "Containers started"
fi

log "Database check completed"
EOL

    # Make the script executable
    chmod +x ${REMOTE_DIR}/server/db_check.sh

    # Create a systemd service for the database check
    echo "Creating database check service..."
    cat > /etc/systemd/system/mnist-db-check.service << EOL
[Unit]
Description=MNIST Database Check
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=${REMOTE_DIR}/server/db_check.sh
EOL

    # Create a systemd timer to run the database check every hour and at boot
    echo "Setting up database check timer..."
    cat > /etc/systemd/system/mnist-db-check.timer << EOL
[Unit]
Description=Run MNIST Database Check regularly

[Timer]
OnBootSec=1min
OnUnitActiveSec=1h

[Install]
WantedBy=timers.target
EOL

    # Enable and start the timer
    systemctl daemon-reload
    systemctl enable mnist-app.service
    systemctl enable mnist-db-check.timer
    systemctl start mnist-db-check.timer
    
    echo "Application URL: http://${REMOTE_HOST}:8501"
    echo "Deployment completed successfully!"
EOF

# Check deployment result
if [ $? -eq 0 ]; then
    log_success "Deployment completed successfully!"
    log_info "You can access the application at: http://${REMOTE_HOST}:8501"
else
    log_error "Deployment failed! Please check the error messages above."
    exit 1
fi 