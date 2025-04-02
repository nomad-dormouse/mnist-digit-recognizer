#!/bin/bash

# LOCAL DEVELOPMENT RUNNER
# This script runs the MNIST Digit Recognizer app locally using Docker Compose.
# 
# Usage:
#   ./local/run_locally.sh
#
# Requirements:
#   - Docker Desktop running
#   - Trained model file in model/saved_models/mnist_model.pth
#   - .env.local file in the local directory
#
# Notes:
#   - All components (app and database) run in Docker containers
#   - Data persists between runs in a Docker volume
#   - The web interface is available at http://localhost:8501

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ENVIRONMENT VARIABLES
echo -e "${GREEN}Loading environment variables...${NC}"
cd "${PROJECT_ROOT}"

if [ -f ".env" ]; then
    echo -e "${GREEN}Loading base environment variables from .env...${NC}"
    set -a
    source ".env"
    set +a
else
    echo -e "${YELLOW}Warning: Base .env file not found. Using only local variables.${NC}"
fi

if [ -f "${SCRIPT_DIR}/.env.local" ]; then
    echo -e "${GREEN}Loading local environment variables from .env.local...${NC}"
    set -a
    source "${SCRIPT_DIR}/.env.local"
    set +a
else
    echo -e "${RED}Error: .env.local file not found in ${SCRIPT_DIR}${NC}"
    echo -e "${YELLOW}Please create .env.local from .env.local.template${NC}"
    exit 1
fi

# PREREQUISITES CHECK
# Check Docker is running
if ! docker ps &>/dev/null; then
    echo -e "${RED}Error: Docker is not running. Start Docker Desktop first.${NC}"
    exit 1
fi

# Check if model file exists
MODEL_FILE="${PROJECT_ROOT}/model/saved_models/mnist_model.pth"
if [ ! -f "${MODEL_FILE}" ]; then
    echo -e "${RED}Error: Model file not found at ${MODEL_FILE}${NC}"
    echo -e "${YELLOW}Please run the training script first:${NC}"
    echo -e "${GREEN}python model/train.py${NC}"
    exit 1
fi

# DOCKER COMPOSE CONFIGURATION
# Define Docker Compose files
COMPOSE_FILES="-f docker-compose.yml -f local/docker-compose.local.override.yml"

# RESOURCE CLEANUP
echo -e "${YELLOW}Cleaning up existing resources...${NC}"
cd "${PROJECT_ROOT}"

# Stop and remove any previous Docker Compose setup
echo -e "${YELLOW}Stopping existing containers...${NC}"
docker compose ${COMPOSE_FILES} down --remove-orphans -v

# Remove any orphaned containers with our names
echo -e "${YELLOW}Removing any orphaned containers...${NC}"
docker rm -f "${WEB_CONTAINER_NAME}" "${DB_CONTAINER_NAME}" 2>/dev/null || true

# Remove the volume if it exists
echo -e "${YELLOW}Removing database volume...${NC}"
docker volume rm mnist-digit-recognizer-db-volume 2>/dev/null || true

# SERVICE STARTUP
echo -e "${YELLOW}Starting services...${NC}"
# Export all environment variables to make them available to Docker Compose
export WEB_CONTAINER_NAME DB_CONTAINER_NAME APP_PORT DB_PORT DB_NAME DB_USER DB_PASSWORD DB_VERSION
export POSTGRES_INITDB_ARGS PGDATA NETWORK_NAME MODEL_PATH

# Run Docker Compose with proper environment variables
docker compose ${COMPOSE_FILES} up -d --build

# Wait a bit for containers to stabilize
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

# DATABASE SETUP
# Create the predictions table
echo -e "${YELLOW}Ensuring database is set up...${NC}"
docker compose ${COMPOSE_FILES} exec db psql -U "${DB_USER}" -d "${DB_NAME}" -c "
    CREATE TABLE IF NOT EXISTS predictions (
        id SERIAL PRIMARY KEY,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        predicted_digit INTEGER NOT NULL,
        true_label INTEGER,
        confidence FLOAT NOT NULL
    );" > /dev/null 2>&1

# USER INFORMATION
# Show the URL and open browser
echo -e "\n${GREEN}App running at http://localhost:${APP_PORT}${NC}"
echo -e "${YELLOW}Opening browser...${NC}"
open "http://localhost:${APP_PORT}"

# Show helpful information
echo -e "\n${YELLOW}Helpful commands:${NC}"
echo -e "  ${GREEN}docker compose ${COMPOSE_FILES} logs -f web${NC}  - View application logs"
echo -e "  ${GREEN}docker compose ${COMPOSE_FILES} exec db psql -U ${DB_USER} -d ${DB_NAME}${NC} - Connect to database"
echo -e "  ${GREEN}docker compose ${COMPOSE_FILES} down -v${NC} - Stop and clean up all resources"