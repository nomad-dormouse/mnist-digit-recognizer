#!/bin/bash
# REMOTE EXECUTION SCRIPT FOR MNIST DIGIT RECOGNISER

# Set error handling
set -e
trap 'echo -e "${RED}Remote deployment script ${REMOTE_DEPLOYMENT_SCRIPT} terminated${NC}"; exit 1' ERR

# Change to script directory which is project root
cd "$(dirname "${BASH_SOURCE[0]}")"

# First, load environment variables
if [[ -f ".env" ]]; then
    source ".env"
else
    echo -e "ERROR: .env file not found"
    exit 1
fi

# Now we can use variables from .env
echo -e "\n${BLUE}Running remote deployment script ${REMOTE_DEPLOYMENT_SCRIPT}...${NC}"

# Connect to the remote server and execute the local deployment script
ssh -t -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" << EOF
    set -e
    trap 'echo -e "${RED}Command failed at line $LINENO${NC}"; exit 1' ERR

    echo -e "${GREEN}Connected to remote server ${REMOTE_USER}@${REMOTE_HOST}${NC}"

    DISK_SPACE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$DISK_SPACE" -gt 85 ]; then
        echo -e "${BLUE}Disk is ${DISK_SPACE}% full, cleaning up...${NC}"
        docker system prune -f
    fi
    
    if [ -d "${REMOTE_DIR}" ]; then
        echo -e "\n${BLUE}Directory ${REMOTE_DIR} exists, removing it...${NC}"
        rm -rf "${REMOTE_DIR}" || { echo -e "${RED}Failed to remove directory ${REMOTE_DIR}${NC}"; exit 1; }
    fi
    
    echo -e "${BLUE}Cloning repository ${REPO_URL}...${NC}"
    git clone "${REPO_URL}" || { echo -e "${RED}Failed to clone${NC}"; exit 1; }

    echo -e "\n${BLUE}Navigating to ${REMOTE_DIR} directory...${NC}"
    cd ${REMOTE_DIR} || { echo -e "${RED}Failed to navigate to directory${NC}"; exit 1; }
    ./${LOCAL_DEPLOYMENT_SCRIPT} || { echo -e "${RED}Failed to run local deployment script ${LOCAL_DEPLOYMENT_SCRIPT} successfully${NC}"; exit 1; }
    
EOF

# If we reached here, everything went well
echo -e "${GREEN}Deployment on remote server completed successfully${NC}"