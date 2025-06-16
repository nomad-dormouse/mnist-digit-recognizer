#!/bin/bash

# Change to script directory which is project root
cd "$(dirname "${BASH_SOURCE[0]}")"

# Load environment variables
if [[ -f ".env" ]]; then
    source ".env"
else
    echo "ERROR: .env file not found"
    exit 1
fi

# Check required environment variables
required_vars=("REMOTE_USER" "REMOTE_HOST" "SSH_KEY" "REMOTE_DIR" "REPO_URL" "WEBAPP_PORT")
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo "ERROR: Required environment variable $var is not set"
        exit 1
    fi
done

echo -e "\n${BLUE}Starting remote deployment for MNIST Digit Recogniser...${NC}"

echo -e "\n${BLUE}Copying .env file to remote server...${NC}"
scp -i "${SSH_KEY}" ".env" "${REMOTE_USER}@${REMOTE_HOST}:/tmp/.env"

echo -e "\n${BLUE}Connecting to remote server and executing deployment script...${NC}"
ssh -t -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" << EOF
    set -e
    trap 'echo "Command failed on remote server"; exit 1' ERR

    echo -e "${GREEN}Connected to remote server ${REMOTE_HOST}${NC}"
    
    echo -e "\n${BLUE}Updating system packages...${NC}"
    sudo apt-get update && \
    sudo apt-get upgrade -y && \
    sudo apt-get autoremove -y && \
    sudo apt-get autoclean
    
    echo -e "\n${BLUE}Cleaning temporary and log files...${NC}"
    sudo find /tmp /var/tmp -type f -mtime +1 -delete 2>/dev/null || true
    sudo find /var/log -type f -name "*.log" -mtime +7 -delete 2>/dev/null || true
    
    echo -e "\n${BLUE}Cloning repository from ${REPO_URL}...${NC}"
    rm -rf "${REMOTE_DIR}"
    git clone "${REPO_URL}"
    cd "${REMOTE_DIR}"
    
    echo -e "\n${BLUE}Copying .env file to project directory...${NC}"
    cp /tmp/.env .env
    chmod 600 .env
    
    echo -e "\n${BLUE}Running deployment script on remote server...${NC}"
    chmod +x deploy.sh
    ./deploy.sh remotely
    
    echo -e "\n${BLUE}Removing deployment files...${NC}"
    rm -f /tmp/.env
EOF