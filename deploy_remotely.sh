#!/bin/bash
# REMOTE EXECUTION SCRIPT FOR MNIST DIGIT RECOGNISER

# Load environment variables from .env
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
fi
source .env

# Set error handling
set -e
trap 'echo -e "${RED}Error: Command failed at line $LINENO${NC}"' ERR

# Check if SSH key exists
if [[ ! -f "${SSH_KEY}" ]]; then
    echo -e "${RED}Error: SSH key not found at ${SSH_KEY}${NC}"
fi

# Function to handle errors
handle_error() {
    local error_message=$1
    echo -e "${RED}Error: ${error_message}${NC}"
}

# Connect to the remote server and execute the deployment script
echo -e "${BLUE}Connecting to remote server ${REMOTE_USER}@${REMOTE_HOST}...${NC}"
ssh -t -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" << EOF || handle_error "Script failed"
    set -e  # Exit immediately if a command exits with a non-zero status
    echo -e "${GREEN}Connected to remote server${NC}"
    
    echo -e "${BLUE}Navigating to remote directory ${REMOTE_DIR}...${NC}"
    cd ${REMOTE_DIR} || { echo -e "${RED}Error: Failed to navigate to ${REMOTE_DIR}${NC}"; }
    
    echo -e "${BLUE}Pulling latest changes from repository...${NC}"
    git pull ${REPO_URL} || { echo -e "${RED}Error: Failed to pull from repository${NC}"; }
    
    echo -e "${BLUE}Running deployment script...${NC}"
    ./deploy.sh || { echo -e "${RED}Error: Failed to run deployment script${NC}"; }
EOF

# If we reached here, everything went well
echo -e "${GREEN}Remote deployment completed successfully.${NC}"