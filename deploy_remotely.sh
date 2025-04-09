#!/bin/bash
# REMOTE EXECUTION SCRIPT FOR MNIST DIGIT RECOGNISER

# Load environment variables from .env
source .env

# Check if SSH key exists
if [[ ! -f "${SSH_KEY}" ]]; then
    echo -e "${RED}Error: SSH key not found at ${SSH_KEY}${NC}"
    exit 1
fi

# Connect to the remote server and execute the deployment script
echo -e "${BLUE}Connecting to remote server ${REMOTE_USER}@${REMOTE_HOST}...${NC}"
ssh -t -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" << EOF
    echo -e "${GREEN}Connected to remote server${NC}"
    
    echo -e "${BLUE}Navigating to remote directory ${REMOTE_DIR}...${NC}"
    cd ${REMOTE_DIR} || exit
    
    echo -e "${BLUE}Pulling latest changes from repository ${REPO_URL}...${NC}"
    git pull ${REPO_URL}
    
    echo -e "${BLUE}Running deployment script...${NC}"
    ./deploy.sh
    
    echo -e "${GREEN}Deployment completed on remote server.${NC}"
EOF