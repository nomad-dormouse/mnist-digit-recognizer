#!/bin/bash
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
NC='\033[0m' # No Color

echo -e "${YELLOW}Deploying MNIST Digit Recognizer to ${REMOTE_HOST}...${NC}"

# Make server_setup.sh script executable
chmod +x scripts/server_setup.sh

# SSH into the remote server and perform deployment
ssh -i ${SSH_KEY} ${REMOTE_USER}@${REMOTE_HOST} << EOF
    # Clone or pull the repository
    if [ -d "${REMOTE_DIR}" ]; then
        echo -e "${YELLOW}Updating existing repository...${NC}"
        cd ${REMOTE_DIR}
        git pull
    else
        echo -e "${YELLOW}Cloning repository...${NC}"
        git clone ${REPO_URL} ${REMOTE_DIR}
        cd ${REMOTE_DIR}
    fi

    # Copy production environment file
    cp .env.production .env

    # Create saved_models directory if it doesn't exist
    mkdir -p saved_models

    # Train the model if it doesn't exist
    if [ ! -f "saved_models/mnist_model.pth" ]; then
        echo -e "${YELLOW}Training the model...${NC}"
        docker run --rm -v \$(pwd):/app -w /app python:3.9-slim bash -c "pip install torch torchvision numpy && python model/train.py"
    fi

    # Build and start the containers
    echo -e "${YELLOW}Building and starting containers...${NC}"
    docker-compose down || true
    
    # Remove the PostgreSQL volume to ensure clean initialization
    echo -e "${YELLOW}Removing PostgreSQL volume for clean initialization...${NC}"
    docker volume rm mnist-digit-recognizer_postgres_data || true
    
    docker-compose build --no-cache
    docker-compose up -d

    # Set up automatic restart on server reboot
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

    systemctl daemon-reload
    systemctl enable mnist-app.service

    echo -e "${GREEN}Deployment completed successfully!${NC}"
    echo -e "${GREEN}The application is now running at http://${REMOTE_HOST}:8501${NC}"
EOF

echo -e "${GREEN}Deployment script executed successfully!${NC}" 