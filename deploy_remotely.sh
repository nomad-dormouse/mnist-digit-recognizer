#!/bin/bash
# REMOTE EXECUTION SCRIPT FOR MNIST DIGIT RECOGNISER

# Set error handling
set -e
trap 'echo "Remote deployment script terminated with error"; exit 1' ERR

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
required_vars=("REMOTE_USER" "REMOTE_HOST" "SSH_KEY" "REMOTE_DIR" "REPO_URL" "WEB_PORT")
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo "ERROR: Required environment variable $var is not set"
        exit 1
    fi
done

echo -e "${BLUE}Starting remote deployment for MNIST Digit Recogniser...${NC}"
echo -e "${BLUE}Connecting to remote server: ${REMOTE_USER}@${REMOTE_HOST}${NC}"

# Connect to the remote server and execute the deployment
ssh -t -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" << EOF
    set -e
    trap 'echo "Command failed on remote server"; exit 1' ERR

    echo -e "${GREEN}Connected to remote server ${REMOTE_HOST}${NC}"
    
    # Check if project directory exists, remove if it does
    if [ -d "${REMOTE_DIR}" ]; then
        echo -e "${BLUE}Removing existing project directory...${NC}"
        rm -rf "${REMOTE_DIR}"
    fi
    
    # Clone the repository
    echo -e "${BLUE}Cloning repository from ${REPO_URL}...${NC}"
    git clone "${REPO_URL}"
    cd "${REMOTE_DIR}"
    
    # Run the deployment script
    echo -e "${BLUE}Running deployment script on remote server...${NC}"
    chmod +x deploy.sh
    ./deploy.sh remotely
EOF