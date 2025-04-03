#!/bin/bash

# LOCAL DEVELOPMENT SCRIPT
# This script runs the MNIST Digit Recognizer app in development mode.
# 
# Usage:
#   ./local/run_locally.sh
#
# Requirements:
#   - Docker and Docker Compose installed
#   - .env file in project root directory
#   - Trained model in model/saved_models/mnist_model.pth

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
export PROJECT_ROOT
cd "${PROJECT_ROOT}"

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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

# Check if Docker is running
if ! docker ps &>/dev/null; then
    echo -e "${RED}Error: Docker is not running. Start Docker Desktop first.${NC}"
    exit 1
fi

# Check if model file exists
if [ ! -f "${PROJECT_ROOT}/model/saved_models/mnist_model.pth" ]; then
    echo -e "${RED}Error: Model file not found. Please run the training script first.${NC}"
    exit 1
fi

# Stop any existing containers
echo -e "${YELLOW}Stopping any existing containers...${NC}"
docker compose down --remove-orphans

# Start services
echo -e "${GREEN}Starting services...${NC}"
docker compose up -d --build

# Wait for containers to stabilize
echo -e "${YELLOW}Waiting for containers to initialize...${NC}"
sleep 5

# Check if containers are running
echo -e "${YELLOW}Checking if containers are running...${NC}"
if ! docker ps --format '{{.Names}}' | grep -q "${WEB_CONTAINER_NAME}"; then
    echo -e "${RED}Error: Web container failed to start. Checking logs:${NC}"
    docker compose logs web
    exit 1
fi
echo -e "${GREEN}Web container is running!${NC}"

# Wait for database to be ready
echo -e "${YELLOW}Waiting for database to initialize...${NC}"
MAX_RETRIES=30
for i in $(seq 1 $MAX_RETRIES); do
    if docker compose exec db pg_isready -U "${DB_USER}" &>/dev/null; then
        echo -e "${GREEN}Database is ready!${NC}"
        break
    fi
    echo -n "."
    sleep 2
    
    if [ $i -eq $MAX_RETRIES ]; then
        echo -e "\n${RED}Database did not initialize in time. Check logs:${NC}"
        docker compose logs db
        exit 1
    fi
done

# Ensure database table exists
echo -e "${YELLOW}Setting up database...${NC}"
docker compose exec db psql -U "${DB_USER}" -d "${DB_NAME}" -c "
    CREATE TABLE IF NOT EXISTS predictions (
        id SERIAL PRIMARY KEY,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        predicted_digit INTEGER NOT NULL,
        true_label INTEGER,
        confidence FLOAT NOT NULL
    );" > /dev/null 2>&1

# Show app URL and open browser
echo -e "\n${GREEN}App running at http://localhost:${APP_PORT}${NC}"
echo -e "${YELLOW}Opening browser...${NC}"
open "http://localhost:${APP_PORT}"

# Show helpful commands
echo -e "\n${YELLOW}Helpful commands:${NC}"
echo -e "  ${GREEN}docker compose logs -f web${NC}  - View application logs"
echo -e "  ${GREEN}docker compose exec db psql -U ${DB_USER} -d ${DB_NAME}${NC} - Connect to database"
echo -e "  ${GREEN}docker compose down${NC} - Stop containers (preserving data)"