#!/bin/bash

# REMOTE DEPLOYMENT SCRIPT
# This script deploys the MNIST Digit Recogniser application to a remote server.
# 
# Usage:
#   ./deploy_remotely.sh [command]
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

# Load environment variables locally (for SSH connection details)
if [ -f ".env" ]; then
    echo -e "${GREEN}Loading local environment variables from .env...${NC}"
    set -a
    source ".env"
    set +a
else
    echo -e "${RED}Error: .env file not found locally.${NC}"
    exit 1
fi

# Verify SSH connection to remote server
echo -e "${BLUE}Verifying SSH connection to ${REMOTE_USER}@${REMOTE_HOST}...${NC}"
if ssh -i "${SSH_KEY}" -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${REMOTE_USER}@${REMOTE_HOST}" "echo 'SSH connection successful'" &> /dev/null; then
    echo -e "${GREEN}SSH connection established successfully.${NC}"
else
    echo -e "${RED}Error: Could not establish SSH connection to ${REMOTE_USER}@${REMOTE_HOST}${NC}"
    echo -e "${YELLOW}Please verify:${NC}"
    echo -e "  - SSH key at ${SSH_KEY} is correct and has proper permissions (chmod 600)"
    echo -e "  - Remote host ${REMOTE_HOST} is reachable"
    echo -e "  - User ${REMOTE_USER} has access to the remote host"
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
            cd ${REMOTE_DIR} 2>/dev/null && docker-compose down || true
            rm -rf ${REMOTE_DIR}/*
        "

        # Create and copy deployment package
        echo -e "${YELLOW}Creating deployment package...${NC}"
        TEMP_DIR=$(mktemp -d)

        # Copy required files
        cp -r requirements.txt .env init.sql app.py "${TEMP_DIR}/"
        cp docker-compose.yml Dockerfile "${TEMP_DIR}/"

        # Create model directory and copy only the essential files
        mkdir -p "${TEMP_DIR}/model"
        cp model/model.py "${TEMP_DIR}/model/"  # Only the model definition file
        cp model/trained_model.pth "${TEMP_DIR}/model/"  # The trained model file

        # Verify model file was copied
        if [ -f "${TEMP_DIR}/model/trained_model.pth" ]; then
            echo -e "${GREEN}Model file successfully copied${NC}"
            ls -la "${TEMP_DIR}/model/"
        else
            echo -e "${RED}Error: Model file not copied. Aborting deployment.${NC}"
            exit 1
        fi

        # Create remote directory and copy files
        echo -e "${BLUE}Copying files to remote server...${NC}"
        ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${REMOTE_DIR}"
        scp -i "${SSH_KEY}" -r "${TEMP_DIR}/"* "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"

        # Clean up temp directory
        rm -rf "${TEMP_DIR}"

        # Verify .env file on remote server
        echo -e "${BLUE}Verifying .env file on remote server...${NC}"
        ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" "
            cd ${REMOTE_DIR}
            if [ -f '.env' ]; then
                echo 'Environment file exists and has the following permissions:'
                ls -la .env
                echo 'First 10 lines of .env file:'
                head -n 10 .env
                echo 'Environment variables that will be used by Docker Compose:'
                grep -v '^#' .env | grep '=' | grep -v '^$' | sort
            else
                echo '${RED}Error: .env file not found on remote server!${NC}'
                exit 1
            fi
        "

        # Deploy on remote server
        echo -e "${BLUE}Deploying application...${NC}"
        ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" "
            cd ${REMOTE_DIR}
            # Source .env file before running docker-compose to ensure variables are available
            set -a
            source .env
            set +a
            docker-compose down
            docker-compose up -d
        "

        echo -e "${GREEN}Deployment completed!${NC}"
        echo -e "${GREEN}The application should be available at: http://${REMOTE_HOST}:${APP_PORT}${NC}"
        
        # Wait a moment for containers to start
        echo -e "${BLUE}Waiting for containers to initialize...${NC}"
        sleep 5
        
        # Check file existence in container
        echo -e "${BLUE}Checking model file in container...${NC}"
        ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" << EOF
cd ${REMOTE_DIR}
WEB_CONTAINER=\$(docker ps | grep "${WEB_CONTAINER_NAME}" | awk '{print \$1}')
if [ ! -z "\${WEB_CONTAINER}" ]; then
    echo "Container file check:"
    docker exec \${WEB_CONTAINER} ls -la /app/model
    echo "Model path environment variable:"
    docker exec \${WEB_CONTAINER} sh -c 'echo \$MODEL_PATH'
else
    echo "Container not found"
fi
EOF

        # Show application logs
        echo -e "${BLUE}Application logs:${NC}"
        ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" << EOF
cd ${REMOTE_DIR}
WEB_CONTAINER=\$(docker ps | grep "${WEB_CONTAINER_NAME}" | awk '{print \$1}')
if [ ! -z "\${WEB_CONTAINER}" ]; then
    docker logs \${WEB_CONTAINER} --tail 100
else
    echo "Container not found"
fi
EOF

        # After starting containers, add this:
        echo -e "${BLUE}Checking container status...${NC}"
        ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" "
            cd ${REMOTE_DIR}
            docker ps -a
            echo 'Container logs:'
            docker logs mnist-digit-recogniser-web || echo 'Container not found or failed to start'
        "

        # After starting containers, add this check for environment variables
        echo -e "${BLUE}Verifying environment variables in container...${NC}"
        ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" "
            cd ${REMOTE_DIR}
            WEB_CONTAINER=\$(docker ps | grep mnist-digit-recogniser-web | awk '{print \$1}')
            if [ ! -z \"\${WEB_CONTAINER}\" ]; then
                echo 'Environment variables in container:'
                docker exec \${WEB_CONTAINER} env | sort
            else
                echo 'Container not found, cannot check environment variables'
            fi
        "
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