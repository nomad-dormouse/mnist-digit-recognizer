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

# Handle different commands
case ${COMMAND} in
    deploy)
        # Check dependencies
        echo -e "${BLUE}Checking dependencies...${NC}"
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

        # Check if model file exists
        MODEL_FILE="${ROOT_DIR}/model/trained_model.pth"
        if [ ! -f "${MODEL_FILE}" ]; then
            echo -e "${RED}Error: Model file not found at ${MODEL_FILE}${NC}"
            echo -e "${YELLOW}Please run the training script to generate the model first.${NC}"
            exit 1
        fi

        # Check SSH key exists
        if [ ! -f "${SSH_KEY}" ]; then
            echo -e "${RED}Error: SSH key not found at ${SSH_KEY}${NC}"
            exit 1
        fi

        # Begin deployment
        echo -e "${YELLOW}MNIST DIGIT RECOGNIZER - REMOTE DEPLOYMENT${NC}"

        # Create deployment package
        echo -e "${YELLOW}Creating deployment package...${NC}"
        TEMP_DIR=$(mktemp -d)
        
        mkdir -p "${TEMP_DIR}/model"
        cp -r docker-compose.yml Dockerfile requirements.txt .env init.sql "${TEMP_DIR}/"
        cp -r model/trained_model.pth "${TEMP_DIR}/model/"
        cp -r app.py "${TEMP_DIR}/"
        
        # Create deploy script on remote
        cat > "${TEMP_DIR}/deploy.sh" << 'EOF'
#!/bin/bash

set -e

# Load environment variables
set -a
source .env
set +a

# Set IS_DEVELOPMENT to false for production
export IS_DEVELOPMENT=false

# Ensure Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running on the remote server"
  exit 1
fi

# Stop any existing containers
docker-compose down --remove-orphans

# Create a docker-compose.override.yml with production settings
cat > docker-compose.override.yml << 'EOL'
# PRODUCTION ENVIRONMENT SETTINGS
services:
  web:
    restart: unless-stopped
    environment:
      - IS_DEVELOPMENT=false
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          memory: 512M

  db:
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          memory: 256M
EOL

# Start services
docker-compose up -d --build

# Wait for services to start
sleep 10

# Check if containers are running
if ! docker ps | grep -q "${WEB_CONTAINER_NAME}" || ! docker ps | grep -q "${DB_CONTAINER_NAME}"; then
  echo "Error: Containers failed to start"
  docker-compose logs
  exit 1
fi

# Wait for DB to be ready
MAX_RETRIES=30
for i in $(seq 1 $MAX_RETRIES); do
  if docker-compose exec -T db pg_isready -U "${DB_USER}" &>/dev/null; then
    echo "Database is ready!"
    break
  fi
  echo -n "."
  sleep 2
  
  if [ $i -eq $MAX_RETRIES ]; then
    echo "Database did not initialize in time"
    docker-compose logs db
    exit 1
  fi
done

# Create tables
docker-compose exec -T db psql -U "${DB_USER}" -d "${DB_NAME}" -c "
  CREATE TABLE IF NOT EXISTS predictions (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    predicted_digit INTEGER NOT NULL,
    true_label INTEGER,
    confidence FLOAT NOT NULL
  );" > /dev/null 2>&1

echo "Deployment completed successfully!"
echo "The application is available at http://$(hostname -I | awk '{print $1}'):${APP_PORT}"
EOF
        
        chmod +x "${TEMP_DIR}/deploy.sh"
        
        # Prepare and deploy to remote server
        echo -e "${YELLOW}Preparing remote server...${NC}"
        ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${REMOTE_DIR}"
        
        echo -e "${YELLOW}Copying files to remote server...${NC}"
        scp -i "${SSH_KEY}" -r "${TEMP_DIR}/"* "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
        
        rm -rf "${TEMP_DIR}"
        
        # Execute deployment on remote server
        echo -e "${YELLOW}Executing deployment on remote server...${NC}"
        ssh -i "${SSH_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" "cd ${REMOTE_DIR} && ./deploy.sh"
        
        echo -e "\n${GREEN}DEPLOYMENT COMPLETED SUCCESSFULLY!${NC}"
        echo -e "${GREEN}The web interface is available at http://${REMOTE_HOST}:${APP_PORT}${NC}"
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