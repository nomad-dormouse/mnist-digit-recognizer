#!/bin/bash
# Remote deployment script for MNIST Digit Recognizer (located in local folder)

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Change to project root directory
cd "$PROJECT_ROOT"

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Default server settings
SERVER_USER="ubuntu"
SERVER_IP=${SERVER_IP:-"37.27.197.79"}
SSH_KEY=${SSH_KEY:-"~/.ssh/id_rsa"}
REMOTE_DIR=${REMOTE_DIR:-"/home/ubuntu/mnist-app"}

# Parse command line arguments
ACTION="deploy"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ip)
            SERVER_IP="$2"
            shift 2
            ;;
        --user)
            SERVER_USER="$2"
            shift 2
            ;;
        --key)
            SSH_KEY="$2"
            shift 2
            ;;
        --dir)
            REMOTE_DIR="$2"
            shift 2
            ;;
        status|logs|deploy|start|stop|restart)
            ACTION="$1"
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Usage: $0 [--ip SERVER_IP] [--user SERVER_USER] [--key SSH_KEY] [--dir REMOTE_DIR] [action]"
            echo "Actions: deploy (default), start, stop, restart, status, logs"
            exit 1
            ;;
    esac
done

# Set production environment variables
export IS_DEVELOPMENT=false
export PORT=8501
export DB_CONTAINER_NAME=mnist-digit-recognizer-db
export WEB_CONTAINER_NAME=mnist-digit-recognizer-web
export DB_NAME=mnist_db
export DB_USER=postgres
export DB_PASSWORD=postgres
export DB_HOST=db
export DB_PORT=5432

# Create production override file for remote deployment
PROD_OVERRIDE="$SCRIPT_DIR/docker-compose.prod.yml"
cat > "$PROD_OVERRIDE" << EOF
version: '3.8'

services:
  web:
    restart: always
    ports:
      - "${PORT}:8501"
    environment:
      - KMP_DUPLICATE_LIB_OK=TRUE
      - IS_DEVELOPMENT=false
      - DB_HOST=db
      - DB_PORT=5432
      - DB_NAME=mnist_db
      - DB_USER=postgres
      - DB_PASSWORD=postgres
    depends_on:
      - db
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 500M

  db:
    restart: always
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=mnist_db
    deploy:
      resources:
        limits:
          cpus: '0.3'
          memory: 300M

volumes:
  postgres_data:
EOF

# Function to execute remote commands
remote_exec() {
    ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "$1"
}

# Function to copy files to remote server
remote_copy() {
    scp -i "$SSH_KEY" "$1" "$SERVER_USER@$SERVER_IP:$2"
}

case "$ACTION" in
    deploy)
        echo -e "${YELLOW}Deploying to remote server: $SERVER_IP...${NC}"
        
        # Create remote directory if it doesn't exist
        remote_exec "mkdir -p $REMOTE_DIR"
        
        # Copy necessary files
        echo -e "${BLUE}Copying application files...${NC}"
        remote_copy "app.py" "$REMOTE_DIR/"
        remote_copy "Dockerfile" "$REMOTE_DIR/"
        remote_copy "docker-compose.yml" "$REMOTE_DIR/"
        remote_copy "$PROD_OVERRIDE" "$REMOTE_DIR/docker-compose.override.yml"
        remote_copy "requirements.txt" "$REMOTE_DIR/"
        remote_copy "$SCRIPT_DIR/deploy_base.sh" "$REMOTE_DIR/deploy_base.sh"
        
        # Create model directory and copy model
        remote_exec "mkdir -p $REMOTE_DIR/model/saved_models"
        remote_copy "model/model.py" "$REMOTE_DIR/model/"
        remote_copy "model/saved_models/mnist_model.pth" "$REMOTE_DIR/model/saved_models/"
        
        # Set execute permissions
        remote_exec "chmod +x $REMOTE_DIR/deploy_base.sh"
        
        # Run deploy script on remote server
        echo -e "${GREEN}Starting application on remote server...${NC}"
        remote_exec "cd $REMOTE_DIR && ./deploy_base.sh -e production up"
        
        echo -e "${GREEN}Deployment complete!${NC}"
        echo -e "Access the application at: ${BLUE}http://$SERVER_IP:$PORT${NC}"
        ;;
        
    start)
        echo -e "${YELLOW}Starting application on remote server...${NC}"
        remote_exec "cd $REMOTE_DIR && ./deploy_base.sh -e production up"
        ;;
        
    stop)
        echo -e "${YELLOW}Stopping application on remote server...${NC}"
        remote_exec "cd $REMOTE_DIR && ./deploy_base.sh -e production down"
        ;;
        
    restart)
        echo -e "${YELLOW}Restarting application on remote server...${NC}"
        remote_exec "cd $REMOTE_DIR && ./deploy_base.sh -e production restart"
        ;;
        
    status)
        echo -e "${YELLOW}Checking status on remote server...${NC}"
        remote_exec "cd $REMOTE_DIR && ./deploy_base.sh -e production status"
        ;;
        
    logs)
        echo -e "${YELLOW}Viewing logs from remote server...${NC}"
        remote_exec "cd $REMOTE_DIR && ./deploy_base.sh -e production logs"
        ;;
        
    *)
        echo -e "${RED}Unknown action: $ACTION${NC}"
        echo "Usage: $0 [--ip SERVER_IP] [--user SERVER_USER] [--key SSH_KEY] [--dir REMOTE_DIR] [action]"
        echo "Actions: deploy (default), start, stop, restart, status, logs"
        exit 1
        ;;
esac 