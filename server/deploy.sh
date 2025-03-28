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
    mkdir -p saved_models

    # Check dependencies
    echo "Checking dependencies..."
    for cmd in docker docker-compose; do
        if ! command -v \$cmd &> /dev/null; then
            echo "\$cmd not found! Please install \$cmd first."
            exit 1
        fi
    done

    # Train model if needed
    if [ ! -f "saved_models/mnist_model.pth" ]; then
        echo "Training the model..."
        docker run --rm -v \$(pwd):/app -w /app python:3.9-slim bash -c \
            "pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu torchvision numpy && python model/train.py"
    else
        echo "Model already exists, skipping training."
    fi

    # Prepare containers
    echo "Preparing Docker environment..."
    docker-compose down || true
    docker volume rm mnist-digit-recognizer_postgres_data || true
    
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
    sleep 10

    # Initialize database if needed
    echo "Checking database status..."
    DB_CONTAINER=\$(docker ps | grep -E 'postgres|db' | awk '{print \$1}')
    
    if [ -n "\${DB_CONTAINER}" ]; then
        echo "Checking if database exists..."
        if ! docker exec \${DB_CONTAINER} psql -U postgres -lqt | cut -d \| -f 1 | grep -qw "mnist_db"; then
            echo "Creating mnist_db database..."
            docker exec \${DB_CONTAINER} psql -U postgres -c "CREATE DATABASE mnist_db;"
            
            echo "Initializing database schema..."
            docker exec \${DB_CONTAINER} psql -U postgres -d mnist_db -c "
                CREATE TABLE IF NOT EXISTS predictions (
                    id SERIAL PRIMARY KEY,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    predicted_digit INTEGER NOT NULL,
                    true_label INTEGER,
                    confidence FLOAT NOT NULL
                );
            "
            echo "Database initialized successfully."
        else
            echo "Database mnist_db already exists."
        fi
    else
        echo "Database container not found. Check your docker-compose configuration."
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
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOL

    # Enable service
    systemctl daemon-reload
    systemctl enable mnist-app.service
    
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