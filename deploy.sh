#!/bin/bash

# ================================================================================
# REMOTE SERVER DEPLOYMENT SCRIPT
# ================================================================================
# This script deploys the MNIST Digit Recognizer application to a remote server.
# 
# Usage:
#   ./server/deploy.sh
#
# Requirements:
#   - SSH access to the remote server (Hetzner)
#   - SSH key at ~/.ssh/hatzner_key
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

# Fail on any error
set -e

# Configuration
REMOTE_USER="root"
REMOTE_HOST="37.27.197.79"  # Hetzner server IP
REMOTE_DIR="/root/mnist-digit-recognizer"
REPO_URL="https://github.com/nomad-dormouse/mnist-digit-recognizer.git"
SSH_KEY="~/.ssh/hatzner_key"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if SSH key exists
if [ ! -f "${SSH_KEY}" ]; then
    echo -e "${RED}Error: SSH key not found at ${SSH_KEY}${NC}"
    echo -e "Please ensure your SSH key is correctly set up."
    exit 1
fi

echo -e "${YELLOW}Deploying MNIST Digit Recognizer to ${REMOTE_HOST}...${NC}"

# SSH into the remote server and perform deployment
ssh -i ${SSH_KEY} ${REMOTE_USER}@${REMOTE_HOST} << EOF
    # Exit on error
    set -e
    
    # Clone or pull the repository
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

    echo "Setting up directories..."
    # Set up directories
    mkdir -p saved_models

    # Check for Docker
    if ! command -v docker &> /dev/null; then
        echo "Docker not found! Please install Docker first."
        exit 1
    fi
    
    # Check for Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo "Docker Compose not found! Please install Docker Compose first."
        exit 1
    fi

    # Check if model exists before training
    if [ ! -f "saved_models/mnist_model.pth" ]; then
        echo "Training the model..."
        docker run --rm -v \$(pwd):/app -w /app python:3.9-slim bash -c "pip install --no-cache-dir torch torchvision numpy && python model/train.py"
    else
        echo "Model already exists, skipping training."
    fi

    # Clean up and restart containers
    echo "Restarting containers..."
    docker-compose down || true
    docker volume rm mnist-digit-recognizer_postgres_data || true
    
    # Build and start without cache
    echo "Building containers..."
    docker-compose build --no-cache
    echo "Starting containers..."
    docker-compose up -d
    
    # Verify containers are running
    echo "Verifying containers..."
    docker-compose ps
    
    # Set up systemd service for automatic restart
    echo "Setting up systemd service..."
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

    # Enable service and display status
    systemctl daemon-reload
    systemctl enable mnist-app.service
    
    echo "Application URL: http://${REMOTE_HOST}:8501"
    echo "Deployment completed successfully!"
EOF

# Check if SSH command succeeded
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Deployment script executed successfully!${NC}"
else
    echo -e "${RED}Deployment failed! Please check the error messages above.${NC}"
    exit 1
fi 