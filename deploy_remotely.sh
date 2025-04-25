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
echo -e "\n${BLUE}Connecting to remote server: ${REMOTE_USER}@${REMOTE_HOST}${NC}"

# Connect to the remote server and execute the deployment
ssh -t -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" << EOF
    set -e
    trap 'echo "Command failed on remote server"; exit 1' ERR

    echo -e "${GREEN}Connected to remote server ${REMOTE_HOST}${NC}"
    
    echo -e "\n${BLUE}Checking for system updates...${NC}"
    sudo apt-get update
    echo -e "\n${BLUE}Upgrading system packages...${NC}"
    sudo apt-get upgrade -y
    echo -e "\n${BLUE}Removing unnecessary packages...${NC}"
    sudo apt-get autoremove -y
    echo -e "\n${BLUE}Cleaning package cache...${NC}"
    sudo apt-get clean
    
    echo -e "\n${BLUE}Cloning repository from ${REPO_URL}...${NC}"
    rm -rf "${REMOTE_DIR}"
    git clone "${REPO_URL}"
    cd "${REMOTE_DIR}"
    
    echo -e "\n${BLUE}Running deployment script on remote server...${NC}"
    chmod +x deploy.sh
    ./deploy.sh remotely
EOF