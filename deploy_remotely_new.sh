#!/bin/bash
# REMOTE DEPLOYMENT SCRIPT FOR MNIST DIGIT RECOGNIZER
# This script is a wrapper around deploy.sh for remote deployment

set -e  # Exit on error

# Load environment variables
if [[ -f ".env" ]]; then
    source ".env"
fi

# Default server settings from .env or fallbacks
REMOTE_USER=${REMOTE_USER:-"root"}
REMOTE_HOST=${REMOTE_HOST:-"37.27.197.79"}
SSH_KEY=${SSH_KEY:-"~/.ssh/id_rsa"}
REMOTE_DIR=${REMOTE_DIR:-"/root/mnist-digit-recognizer"}

# Help function
show_help() {
    echo -e "${YELLOW}Usage:${NC} $0 [options] [deploy_args]"
    echo -e "${GREEN}Options:${NC}"
    echo "  --ip IP            Server IP address (default: $REMOTE_HOST)"
    echo "  --user USER        SSH username (default: $REMOTE_USER)"
    echo "  --key KEY_PATH     SSH private key path (default: $SSH_KEY)"
    echo "  --dir REMOTE_DIR   Remote directory (default: $REMOTE_DIR)"
    echo "  -h, --help         Show this help message"
    echo -e "${GREEN}Deploy Args:${NC}"
    echo "  Any additional arguments will be passed to deploy.sh"
    echo -e "${GREEN}Examples:${NC}"
    echo "  $0                       Deploy and start the application on remote server"
    echo "  $0 status                Check status of remote application"
    echo "  $0 down                  Stop remote application"
    echo "  $0 --ip 10.0.0.1 restart Deploy to specific IP and restart"
}

# Parse command line arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Parse options first
while [[ $# -gt 0 && "$1" == --* ]]; do
    case "$1" in
        --ip) REMOTE_HOST="$2"; shift 2 ;;
        --user) REMOTE_USER="$2"; shift 2 ;;
        --key) SSH_KEY="$2"; shift 2 ;;
        --dir) REMOTE_DIR="$2"; shift 2 ;;
        --) shift; break ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Helper functions for SSH and SCP operations
remote_exec() {
    ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" "$1"
}

remote_copy() {
    scp -i "$SSH_KEY" "$1" "$REMOTE_USER@$REMOTE_HOST:$2"
}

# First time setup - create directories and copy files if needed
setup_remote() {
    # Check if we need to set up the remote environment
    if ! remote_exec "test -f $REMOTE_DIR/deploy.sh" > /dev/null 2>&1; then
        echo -e "${YELLOW}Setting up remote environment...${NC}"
        
        # Create remote directory 
        echo -e "${BLUE}Creating remote directories...${NC}"
        remote_exec "mkdir -p $REMOTE_DIR/model"
        
        # Copy application files
        echo -e "${BLUE}Copying application files...${NC}"
        remote_copy "app.py" "$REMOTE_DIR/"
        remote_copy "Dockerfile" "$REMOTE_DIR/"
        remote_copy "docker-compose.yml" "$REMOTE_DIR/"
        remote_copy "requirements.txt" "$REMOTE_DIR/"
        remote_copy "deploy.sh" "$REMOTE_DIR/deploy.sh"
        remote_copy "model/model.py" "$REMOTE_DIR/model/"
        remote_copy "model/trained_model.pth" "$REMOTE_DIR/model/"
        
        # Create environment file
        echo -e "${BLUE}Creating remote environment file...${NC}"
        cat > "/tmp/remote.env" << EOF
# MNIST DIGIT RECOGNIZER ENVIRONMENT VARIABLES
# Remote server configuration

# Database settings
DB_HOST=db
DB_PORT=5432
DB_NAME=mnist_db
DB_USER=postgres
DB_PASSWORD=postgres
DB_VERSION=16

# Application settings
APP_PORT=${APP_PORT:-8501}
MODEL_PATH=/model/trained_model.pth

# Containerisation settings
DOCKER_COMPOSE_FILE=docker-compose.yml
COMPOSE_PROJECT_NAME=mnist-digit-recogniser
WEB_CONTAINER_NAME=mnist-digit-recogniser-web
DB_CONTAINER_NAME=mnist-digit-recogniser-db
DB_VOLUME_NAME=mnist-digit-recogniser-db-volume

# Terminal colors
GREEN='${GREEN}'
YELLOW='${YELLOW}'
BLUE='${BLUE}'
RED='${RED}'
NC='${NC}'

# Remote settings
REMOTE_HOST=$REMOTE_HOST
REMOTE_USER=$REMOTE_USER
REMOTE_DIR=$REMOTE_DIR
EOF
        remote_copy "/tmp/remote.env" "$REMOTE_DIR/.env"
        
        # Set execute permissions
        echo -e "${BLUE}Setting permissions...${NC}"
        remote_exec "chmod +x $REMOTE_DIR/deploy.sh"
        
        echo -e "${GREEN}Remote environment setup complete!${NC}"
    else
        echo -e "${GREEN}Remote environment already set up.${NC}"
    fi
}

# Run deploy.sh on remote server with arguments
run_remote_deploy() {
    local action=""
    local args=""
    
    # If no arguments, default to "up"
    if [[ $# -eq 0 ]]; then
        action="up"
    else
        # First argument is the action
        action="$1"
        shift
        
        # Remaining arguments are passed as-is
        args="$*"
    fi
    
    echo -e "${YELLOW}Running on remote server: ./deploy.sh remote $action $args${NC}"
    remote_exec "cd $REMOTE_DIR && ./deploy.sh remote $action $args"
    
    # Display access URL if starting the application
    if [[ "$action" == "up" || "$action" == "restart" ]]; then
        echo -e "${GREEN}Access the application at: http://$REMOTE_HOST:${APP_PORT:-8501}${NC}"
    fi
}

# Main execution
setup_remote
run_remote_deploy "$@" 