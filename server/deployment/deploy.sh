#!/bin/bash

# ================================================================================
# PRODUCTION DEPLOYMENT SCRIPT
# ================================================================================
# This script deploys the MNIST Digit Recognizer app in production mode.
# 
# Usage:
#   ./server/deployment/deploy.sh
#
# Requirements:
#   - Docker and Docker Compose installed
#   - .env file in server/deployment directory
#   - Trained model in model/saved_models/mnist_model.pth
#
# Notes:
#   - Run this script from the project root directory
#   - The web interface will be available at http://your-server:8501
# ================================================================================

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"

# Load environment variables
if [ -f "${SCRIPT_DIR}/.env" ]; then
    echo -e "${GREEN}Loading environment variables from .env...${NC}"
    set -a
    source "${SCRIPT_DIR}/.env"
    set +a
else
    echo -e "${RED}Error: .env file not found in ${SCRIPT_DIR}${NC}"
    echo -e "${YELLOW}Please create .env from .env.template${NC}"
    exit 1
fi

# Check if model file exists
MODEL_FILE="${PROJECT_ROOT}/model/saved_models/mnist_model.pth"
if [ ! -f "${MODEL_FILE}" ]; then
    echo -e "${RED}Error: Model file not found at ${MODEL_FILE}${NC}"
    exit 1
fi

# Define Docker Compose files
COMPOSE_FILES="-f docker-compose.yml -f docker-compose.prod.override.yml"

# Clean up existing resources
echo -e "${YELLOW}Cleaning up existing resources...${NC}"
cd "${PROJECT_ROOT}"

# Stop and remove any previous Docker Compose setup
echo -e "${YELLOW}Stopping existing containers...${NC}"
docker compose ${COMPOSE_FILES} down --remove-orphans

# Start services
echo -e "${YELLOW}Starting services...${NC}"
docker compose ${COMPOSE_FILES} up -d --build

# Wait for database to be ready
echo -e "${YELLOW}Waiting for database to initialize...${NC}"
for i in {1..60}; do
    if docker compose ${COMPOSE_FILES} exec db pg_isready -U "${DB_USER}" &>/dev/null; then
        echo -e "${GREEN}Database is ready!${NC}"
        break
    fi
    echo -n "."
    sleep 2
    
    if [ $i -eq 60 ]; then
        echo -e "\n${RED}Database did not initialize in time. Please check for errors:${NC}"
        docker compose ${COMPOSE_FILES} logs db
        exit 1
    fi
done

# Show the URL
echo -e "\n${GREEN}App deployed successfully!${NC}"
echo -e "${GREEN}The web interface is available at http://your-server:${APP_PORT}${NC}"

# Show helpful information
echo -e "\n${YELLOW}Helpful commands:${NC}"
echo -e "  ${GREEN}docker compose ${COMPOSE_FILES} logs -f web${NC}  - View application logs"
echo -e "  ${GREEN}docker compose ${COMPOSE_FILES} exec db psql -U ${DB_USER} -d ${DB_NAME}${NC} - Connect to database"
echo -e "  ${GREEN}docker compose ${COMPOSE_FILES} down${NC} - Stop all services" 