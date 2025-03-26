#!/bin/bash

# Configuration
REMOTE_USER="root"
REMOTE_HOST="37.27.197.79"  # Hetzner server IP
REMOTE_DIR="/root/mnist-digit-recognizer"
SSH_KEY="~/.ssh/hatzner_key"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Redeploying MNIST Digit Recognizer with correct container names...${NC}"

# SSH into the remote server and perform redeployment
ssh -i ${SSH_KEY} ${REMOTE_USER}@${REMOTE_HOST} << EOF
    # Navigate to the project directory
    cd ${REMOTE_DIR}

    echo -e "${YELLOW}Stopping current containers...${NC}"
    docker-compose down

    echo -e "${YELLOW}Pulling latest changes from GitHub...${NC}"
    git pull

    echo -e "${YELLOW}Building and starting containers with correct names...${NC}"
    docker-compose up -d --force-recreate

    echo -e "${YELLOW}Verifying containers are running...${NC}"
    docker ps | grep mnist-digit-recognizer

    echo -e "${GREEN}Redeployment completed successfully!${NC}"
    echo -e "${GREEN}The application is now running at http://${REMOTE_HOST}:8501${NC}"
EOF

echo -e "${GREEN}Redeployment script executed successfully!${NC}"
echo -e "${GREEN}You can now connect to the database using:${NC}"
echo -e "${GREEN}./scripts/view_db.sh${NC}" 