#!/bin/bash
set -e

# Configuration
REMOTE_USER="root"
REMOTE_HOST="your-server-ip"  # Replace with your server IP
REMOTE_DIR="/root/mnist-digit-recognizer"
REPO_URL="https://github.com/nomad-dormouse/mnist-digit-recognizer.git"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Deploying MNIST Digit Recognizer to ${REMOTE_HOST}...${NC}"

# SSH into the remote server and perform deployment
ssh ${REMOTE_USER}@${REMOTE_HOST} << EOF
    # Install Docker if not already installed
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Installing Docker...${NC}"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
    fi

    # Install Docker Compose if not already installed
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}Installing Docker Compose...${NC}"
        curl -L "https://github.com/docker/compose/releases/download/v2.5.0/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi

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

    # Build and start the containers
    echo -e "${YELLOW}Building and starting containers...${NC}"
    docker-compose down || true
    docker-compose build --no-cache
    docker-compose up -d

    echo -e "${GREEN}Deployment completed successfully!${NC}"
    echo -e "${GREEN}The application is now running at http://${REMOTE_HOST}:8501${NC}"
EOF

echo -e "${GREEN}Deployment script executed successfully!${NC}" 