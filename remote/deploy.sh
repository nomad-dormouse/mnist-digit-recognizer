#!/bin/bash

# PRODUCTION DEPLOYMENT SCRIPT
# This script deploys the MNIST Digit Recognizer app in production mode.
# 
# Usage:
#   ./remote/deploy.sh
#
# Requirements:
#   - Docker and Docker Compose installed
#   - .env file in project root directory
#   - .env.remote file in remote directory
#   - Trained model in model/saved_models/mnist_model.pth
#
# Notes:
#   - Run this script from the project root directory
#   - The web interface will be available at http://your-server:8501
#   - Database data persists between deployments

# INITIALIZATION
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ENVIRONMENT VARIABLES
echo -e "${GREEN}Loading environment variables...${NC}"
cd "${PROJECT_ROOT}"

# Load base environment variables
if [ -f ".env" ]; then
    echo -e "${GREEN}Loading base environment variables from .env...${NC}"
    set -a
    source ".env"
    set +a
else
    echo -e "${RED}Error: Base .env file not found.${NC}"
    echo -e "${YELLOW}Please ensure you have a .env file in the project root.${NC}"
    exit 1
fi

# Load remote environment variables
if [ -f "${SCRIPT_DIR}/.env.remote" ]; then
    echo -e "${GREEN}Loading remote environment variables from .env.remote...${NC}"
    set -a
    source "${SCRIPT_DIR}/.env.remote"
    set +a
else
    echo -e "${RED}Error: .env.remote file not found in ${SCRIPT_DIR}${NC}"
    echo -e "${YELLOW}Please create .env.remote file in the remote directory.${NC}"
    exit 1
fi

# PREREQUISITES CHECK
# Check Docker is running
if ! docker ps &>/dev/null; then
    echo -e "${RED}Error: Docker is not running. Start Docker first.${NC}"
    exit 1
fi

# Check if model file exists
MODEL_FILE="${PROJECT_ROOT}/model/saved_models/mnist_model.pth"
if [ ! -f "${MODEL_FILE}" ]; then
    echo -e "${RED}Error: Model file not found at ${MODEL_FILE}${NC}"
    echo -e "${YELLOW}Please run the training script to generate the model first.${NC}"
    exit 1
fi

# DOCKER COMPOSE CONFIGURATION
# Define Docker Compose files
COMPOSE_FILES="-f docker-compose.yml -f remote/docker-compose.remote.override.yml"

# RESOURCE CLEANUP
echo -e "${YELLOW}Cleaning up existing resources...${NC}"
cd "${PROJECT_ROOT}"

# Stop and remove any previous Docker Compose setup (preserving volumes)
echo -e "${YELLOW}Stopping existing containers (preserving volumes)...${NC}"
docker compose ${COMPOSE_FILES} down --remove-orphans

# Remove any orphaned containers with our names
echo -e "${YELLOW}Removing any orphaned containers...${NC}"
if [[ -n "${WEB_CONTAINER_NAME}" ]] && [[ -n "${DB_CONTAINER_NAME}" ]]; then
    docker rm -f "${WEB_CONTAINER_NAME}" "${DB_CONTAINER_NAME}" 2>/dev/null || true
else
    echo -e "${YELLOW}Warning: Container name variables are not set. Skipping orphaned container removal.${NC}"
fi

# SERVICE STARTUP
echo -e "${YELLOW}Starting services...${NC}"

# Export required environment variables for Docker Compose
echo -e "${GREEN}Preparing environment for Docker Compose...${NC}"

# Database variables
export DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD DB_VERSION
export POSTGRES_INITDB_ARGS PGDATA

# Application variables
export APP_PORT MODEL_PATH

# Container variables
export WEB_CONTAINER_NAME DB_CONTAINER_NAME
export DOCKERFILE_PATH DB_VOLUME_NAME

# Run Docker Compose with proper environment variables
echo -e "${GREEN}Starting Docker Compose services...${NC}"
docker compose ${COMPOSE_FILES} up -d --build

# Wait a bit for containers to stabilize
echo -e "${YELLOW}Waiting for containers to stabilize...${NC}"
sleep 5

# HEALTH CHECKS
# Check if containers are running
echo -e "${YELLOW}Checking if containers are running...${NC}"
if ! docker ps --format '{{.Names}}' | grep -q "${WEB_CONTAINER_NAME}" || ! docker ps --format '{{.Names}}' | grep -q "${DB_CONTAINER_NAME}"; then
    echo -e "${RED}Error: Containers did not start properly. Checking logs:${NC}"
    docker compose ${COMPOSE_FILES} logs
    exit 1
fi
echo -e "${GREEN}Both containers are running!${NC}"

# Wait for database to be ready
echo -e "${YELLOW}Waiting for database to initialize...${NC}"
MAX_RETRIES=60
RETRY_INTERVAL=2
for i in $(seq 1 $MAX_RETRIES); do
    if docker compose ${COMPOSE_FILES} exec db pg_isready -U "${DB_USER}" &>/dev/null; then
        echo -e "\n${GREEN}Database is ready!${NC}"
        break
    fi
    echo -n "."
    sleep $RETRY_INTERVAL
    
    if [ $i -eq $MAX_RETRIES ]; then
        echo -e "\n${RED}Database did not initialize in time. Please check for errors:${NC}"
        docker compose ${COMPOSE_FILES} logs db
        exit 1
    fi
done

# DATABASE SETUP
# Create the predictions table if it doesn't exist
echo -e "${YELLOW}Ensuring database is set up...${NC}"
docker compose ${COMPOSE_FILES} exec db psql -U "${DB_USER}" -d "${DB_NAME}" -c "
    CREATE TABLE IF NOT EXISTS predictions (
        id SERIAL PRIMARY KEY,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        predicted_digit INTEGER NOT NULL,
        true_label INTEGER,
        confidence FLOAT NOT NULL
    );" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to create database table. Please check database connection.${NC}"
    docker compose ${COMPOSE_FILES} logs db
    exit 1
fi

# USER INFORMATION
# Show the URL
echo -e "\n${GREEN}App deployed successfully!${NC}"
echo -e "${GREEN}The web interface is available at http://${REMOTE_HOST}:${APP_PORT}${NC}"

# Show helpful information
echo -e "\n${YELLOW}Helpful commands:${NC}"
echo -e "  ${GREEN}docker compose ${COMPOSE_FILES} logs -f web${NC}  - View application logs"
echo -e "  ${GREEN}docker compose ${COMPOSE_FILES} exec db psql -U ${DB_USER} -d ${DB_NAME}${NC} - Connect to database"
echo -e "  ${GREEN}docker compose ${COMPOSE_FILES} down${NC} - Stop all services (preserving data)"
echo -e "  ${GREEN}docker compose ${COMPOSE_FILES} down -v${NC} - Stop all services and remove volumes" 