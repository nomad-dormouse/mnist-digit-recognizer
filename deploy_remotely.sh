#!/bin/bash
# Remote deployment script for MNIST Digit Recognizer

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Change to project root directory
cd "$PROJECT_ROOT"

# Load environment variables
if [[ -f ".env" ]]; then
    source ".env"
fi

# Set color variables with fallbacks
GREEN=${COLOR_GREEN:-'\033[0;32m'}
YELLOW=${COLOR_YELLOW:-'\033[1;33m'}
BLUE=${COLOR_BLUE:-'\033[0;34m'}
RED=${COLOR_RED:-'\033[0;31m'}
NC=${COLOR_NC:-'\033[0m'}

# Default server settings
SERVER_USER=${SERVER_USER:-"ubuntu"}
SERVER_IP=${SERVER_IP:-"37.27.197.79"}
SSH_KEY=${SSH_KEY:-"~/.ssh/id_rsa"}
REMOTE_DIR=${REMOTE_DIR:-"/home/ubuntu/mnist-app"}
APP_PORT=${APP_PORT:-8501}

# Parse command line arguments
ACTION="deploy"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ip) SERVER_IP="$2"; shift 2 ;;
        --user) SERVER_USER="$2"; shift 2 ;;
        --key) SSH_KEY="$2"; shift 2 ;;
        --dir) REMOTE_DIR="$2"; shift 2 ;;
        --port) APP_PORT="$2"; shift 2 ;;
        status|logs|deploy|start|stop|restart) ACTION="$1"; shift ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Usage: $0 [--ip SERVER_IP] [--user SERVER_USER] [--key SSH_KEY] [--dir REMOTE_DIR] [--port APP_PORT] [action]"
            echo "Actions: deploy (default), start, stop, restart, status, logs"
            exit 1
            ;;
    esac
done

# Helper functions
remote_exec() { ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "$1"; }
remote_copy() { scp -i "$SSH_KEY" "$1" "$SERVER_USER@$SERVER_IP:$2"; }

# Handle the action
case "$ACTION" in
    deploy)
        echo -e "${YELLOW}Deploying to remote server: $SERVER_IP...${NC}"
        
        # Create remote directory 
        remote_exec "mkdir -p $REMOTE_DIR/model/saved_models"
        
        # Copy application files
        echo -e "${BLUE}Copying application files...${NC}"
        remote_copy "app.py" "$REMOTE_DIR/"
        remote_copy "Dockerfile" "$REMOTE_DIR/"
        remote_copy "docker-compose.yml" "$REMOTE_DIR/"
        remote_copy "requirements.txt" "$REMOTE_DIR/"
        remote_copy "deploy.sh" "$REMOTE_DIR/deploy.sh"
        remote_copy "model/model.py" "$REMOTE_DIR/model/"
        remote_copy "model/saved_models/mnist_model.pth" "$REMOTE_DIR/model/saved_models/"
        
        # Create environment file
        echo -e "${BLUE}Creating remote environment file...${NC}"
        cat > "/tmp/remote.env" << EOF
# Remote server configuration
SERVER_IP=$SERVER_IP
APP_PORT=$APP_PORT
REMOTE_HOST=db
LOCAL_HOST=localhost
COLOR_GREEN='$GREEN'
COLOR_YELLOW='$YELLOW'
COLOR_BLUE='$BLUE'
COLOR_RED='$RED'
COLOR_NC='$NC'
EOF
        remote_copy "/tmp/remote.env" "$REMOTE_DIR/.env"
        
        # Set execute permissions and start app
        remote_exec "chmod +x $REMOTE_DIR/deploy.sh"
        echo -e "${GREEN}Starting application on remote server...${NC}"
        remote_exec "cd $REMOTE_DIR && ./deploy.sh remote up"
        
        echo -e "${GREEN}Deployment complete!${NC}"
        echo -e "${GREEN}Access the application at: ${NC}http://$SERVER_IP:$APP_PORT"
        ;;
        
    start|stop|restart|status|logs)
        echo -e "${YELLOW}Running '$ACTION' on remote server...${NC}"
        remote_exec "cd $REMOTE_DIR && ./deploy.sh remote $ACTION"
        ;;
        
    *)
        echo -e "${RED}Unknown action: $ACTION${NC}"
        echo "Usage: $0 [--ip SERVER_IP] [--user SERVER_USER] [--key SSH_KEY] [--dir REMOTE_DIR] [--port APP_PORT] [action]"
        echo "Actions: deploy (default), start, stop, restart, status, logs"
        exit 1
        ;;
esac 