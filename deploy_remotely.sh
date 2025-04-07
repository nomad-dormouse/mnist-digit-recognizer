#!/bin/bash

# REMOTE DEPLOYMENT SCRIPT
# This script deploys the MNIST Digit Recognizer application to a remote server.
# 
# Usage:
#   ./deploy.sh [command]
#
# Commands:
#   deploy   - Deploy application to remote server (default)
#   logs     - View application logs
#   db       - View database content
#   status   - Check application status
#   stop     - Stop all services

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}"
cd "${ROOT_DIR}"

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default command is "deploy"
COMMAND=${1:-deploy}

# Load environment variables
if [ -f ".env" ]; then
    echo -e "${GREEN}Loading environment variables from .env...${NC}"
    set -a
    source ".env"
    set +a
else
    echo -e "${RED}Error: .env file not found.${NC}"
    exit 1
fi

# Function to check and prepare remote server
check_remote_server() {
    echo -e "${BLUE}Checking remote server status...${NC}"
    
    # Check disk space and system updates
    ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" '
        echo "=== Disk Space Status ==="
        df -h /
        
        # Check if disk usage is over 90%
        DISK_USAGE=$(df / | tail -1 | awk '"'"'{print $5}'"'"' | sed '"'"'s/%//'"'"')
        if [ "$DISK_USAGE" -gt 90 ]; then
            echo -e "\n=== Cleaning up disk space ==="
            # Clean Docker
            if command -v docker &> /dev/null; then
                echo "Cleaning Docker resources..."
                docker system prune -af --volumes
            fi
            
            # Clean package manager
            echo "Cleaning package manager cache..."
            apt-get clean
            apt-get autoremove -y
            
            echo -e "\n=== Updated Disk Space Status ==="
            df -h /
        fi
        
        echo -e "\n=== System Update Status ==="
        if [ -f /var/run/reboot-required ]; then
            echo -e "${YELLOW}System restart required${NC}"
        fi
        
        UPDATES=$(apt list --upgradable 2>/dev/null | wc -l)
        if [ "$UPDATES" -gt 1 ]; then
            echo -e "${YELLOW}System has $((UPDATES-1)) updates available${NC}"
            echo -e "${BLUE}Would you like to update the system? [y/N]:${NC} "
            read -p "" -n 1 -r REPLY
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo -e "${GREEN}Installing updates...${NC}"
                apt-get update
                apt-get upgrade -y
            else
                echo -e "${YELLOW}Skipping system updates${NC}"
            fi
        else
            echo -e "${GREEN}System is up to date${NC}"
        fi
        
        # Check Docker status
        echo -e "\n=== Docker Status ==="
        if command -v docker &> /dev/null; then
            echo "Docker is installed"
            if systemctl is-active --quiet docker; then
                echo "Docker service is running"
            else
                echo "Starting Docker service..."
                systemctl start docker
                systemctl enable docker
            fi
        else
            echo "Docker is not installed"
        fi
        
        # Check Docker Compose
        echo -e "\n=== Docker Compose Status ==="
        if command -v docker-compose &> /dev/null; then
            echo "Docker Compose is installed"
        else
            echo "Docker Compose is not installed"
        fi
    '
    
    # Check the exit status
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to check remote server status${NC}"
        exit 1
    fi
}

# Handle different commands
case ${COMMAND} in
    deploy)
        # Check dependencies
        echo -e "${BLUE}Checking local dependencies...${NC}"
        DEPS=("ssh" "scp" "git" "docker" "docker-compose")
        MISSING_DEPS=()

        for dep in "${DEPS[@]}"; do
            if ! command -v "$dep" &> /dev/null; then
                MISSING_DEPS+=("$dep")
            fi
        done

        if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
            echo -e "${RED}Error: The following dependencies are missing:${NC}"
            for dep in "${MISSING_DEPS[@]}"; do
                echo -e "${RED}- $dep${NC}"
            done
            echo -e "${YELLOW}Please install them before continuing.${NC}"
            exit 1
        fi

        # Check prerequisites
        if ! docker ps &>/dev/null; then
            echo -e "${RED}Error: Docker is not running. Start Docker first.${NC}"
            exit 1
        fi

        # Check SSH key exists
        if [ ! -f "${SSH_KEY}" ]; then
            echo -e "${RED}Error: SSH key not found at ${SSH_KEY}${NC}"
            exit 1
        fi

        # Check if model file exists
        MODEL_FILE="${ROOT_DIR}/model/trained_model.pth"
        if [ ! -f "${MODEL_FILE}" ]; then
            echo -e "${RED}Error: Model file not found at ${MODEL_FILE}${NC}"
            exit 1
        fi

        # Check remote server status
        check_remote_server

        echo -e "${BLUE}Starting deployment to ${REMOTE_HOST}...${NC}"

        # Clean up any existing deployment
        echo -e "${BLUE}Cleaning up existing deployment...${NC}"
        ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" "
            cd ${REMOTE_DIR} 2>/dev/null && docker-compose down -v || true
            rm -rf ${REMOTE_DIR}/*
        "

        # Create and copy deployment package
        echo -e "${YELLOW}Creating deployment package...${NC}"
        TEMP_DIR=$(mktemp -d)
        mkdir -p "${TEMP_DIR}/model"

        # Copy required files
        cp -r docker-compose.yml Dockerfile requirements.txt .env init.sql app.py "${TEMP_DIR}/"
        # Copy the entire model directory including Python files
        cp -r model/*.py model/trained_model.pth "${TEMP_DIR}/model/"

        # Create remote directory and copy files
        echo -e "${BLUE}Copying files to remote server...${NC}"
        ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${REMOTE_DIR}"
        scp -i "${SSH_KEY}" -r "${TEMP_DIR}/"* "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"

        # Clean up temp directory
        rm -rf "${TEMP_DIR}"

        # Deploy on remote server
        echo -e "${BLUE}Deploying application...${NC}"
        ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" "
            cd ${REMOTE_DIR}
            docker-compose down -v
            docker-compose up -d
        "

        echo -e "${GREEN}Deployment completed!${NC}"
        echo -e "${GREEN}The application should be available at: http://${REMOTE_HOST}:${APP_PORT}${NC}"
        ;;
        
    logs)
        LINES=${2:-50}
        echo -e "${YELLOW}Connecting to ${REMOTE_HOST} to view logs...${NC}"
        
        ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" << EOF
cd ${REMOTE_DIR}

WEB_CONTAINER=\$(docker ps | grep "${WEB_CONTAINER_NAME}" | awk '{print \$1}')

if [ -z "\${WEB_CONTAINER}" ]; then
  echo "Web container not found!"
  exit 1
fi

echo "Found web container: \${WEB_CONTAINER}"
echo "Showing last ${LINES} lines of logs..."
docker logs \${WEB_CONTAINER} --tail ${LINES}
EOF
        ;;
        
    db)
        LIMIT=${2:-10}
        echo -e "${YELLOW}Connecting to ${REMOTE_HOST} to view database...${NC}"
        
        ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" << EOF
cd ${REMOTE_DIR}

DB_CONTAINER=\$(docker ps | grep "${DB_CONTAINER_NAME}" | awk '{print \$1}')

if [ -z "\${DB_CONTAINER}" ]; then
  echo "Database container not found!"
  exit 1
fi

echo "Found database container: \${DB_CONTAINER}"

if [ "${LIMIT}" = "all" ]; then
  echo "Showing all records:"
  docker exec \${DB_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -c "SELECT * FROM predictions ORDER BY timestamp DESC;"
else
  echo "Showing last ${LIMIT} records:"
  docker exec \${DB_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -c "SELECT * FROM predictions ORDER BY timestamp DESC LIMIT ${LIMIT};"
fi
EOF
        ;;
        
    status)
        echo -e "${YELLOW}Checking application status on ${REMOTE_HOST}...${NC}"
        
        ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" << EOF
cd ${REMOTE_DIR}

echo "Container status:"
docker ps

echo "Docker info:"
docker info | grep "Running\|Containers\|Images"

if command -v curl &> /dev/null; then
  echo "Application health check:"
  curl -s -o /dev/null -w "%{http_code}" http://localhost:${APP_PORT} || echo "Failed to connect"
fi
EOF
        ;;
        
    stop)
        echo -e "${YELLOW}Stopping services on ${REMOTE_HOST}...${NC}"
        
        ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" << EOF
cd ${REMOTE_DIR}
docker-compose down
echo "Services stopped"
EOF
        ;;
        
    *)
        echo -e "${RED}Error: Unknown command '${COMMAND}'${NC}"
        echo -e "Available commands: deploy, logs, db, status, stop"
        exit 1
        ;;
esac 