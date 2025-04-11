#!/bin/bash
# REMOTE EXECUTION SCRIPT FOR MNIST DIGIT RECOGNISER

# Set error handling
set -e
trap 'echo -e "${RED}Script terminated${NC}"; exit 1' ERR

# Connect to the remote server and execute the deployment script
ssh -t -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" << EOF
    set -e
    trap 'echo -e "${RED}Command failed at line $LINENO${NC}"; exit 1' ERR

    echo -e "${GREEN}Connected to remote server ${REMOTE_USER}@${REMOTE_HOST}${NC}"
    
    if [ -d "${REMOTE_DIR}" ]; then
        echo -e "\n${BLUE}Directory ${REMOTE_DIR} exists, removing it...${NC}"
        rm -rf "${REMOTE_DIR}" || { echo -e "${RED}Failed to remove directory ${REMOTE_DIR}${NC}"; exit 1; }
    fi
    
    echo -e "${BLUE}Cloning repository ${REPO_URL}...${NC}"
    git clone "${REPO_URL}" || { echo -e "${RED}Failed to clone${NC}"; exit 1; }

    echo -e "\n${BLUE}Navigating to ${REMOTE_DIR} directory...${NC}"
    cd ${REMOTE_DIR} || { echo -e "${RED}Failed to navigate to directory${NC}"; exit 1; }
    echo -e "${BLUE}Running deployment script deploy.sh...${NC}"
    ./deploy.sh || { echo -e "${RED}Failed to run script${NC}"; exit 1; }
    
EOF

# If we reached here, everything went well
echo -e "${GREEN}Deployment on remote server completed successfully${NC}"