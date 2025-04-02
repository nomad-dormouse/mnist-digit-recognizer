#!/bin/bash

# ================================================================================
# LOCAL DEVELOPMENT RUNNER
# ================================================================================
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
# ================================================================================

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Load environment variables
if [ -f "${SCRIPT_DIR}/.env.local" ]; then
    echo -e "${GREEN}Loading environment variables from .env.local...${NC}"
    source "${SCRIPT_DIR}/.env.local"
else
    echo -e "${RED}Error: .env.local file not found in ${SCRIPT_DIR}${NC}"
    echo -e "${YELLOW}Please create .env.local from .env.local.template${NC}"
    exit 1
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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

# Clean up existing resources
echo -e "${YELLOW}Cleaning up existing resources...${NC}"
cd "${SCRIPT_DIR}" && docker compose -f docker-compose.local.yml down -v

# Start services
echo -e "${YELLOW}Starting services...${NC}"
docker compose -f docker-compose.local.yml up -d --build

# Wait for database to be ready
echo -e "${YELLOW}Waiting for database to initialize...${NC}"
for i in {1..30}; do
    if docker compose -f docker-compose.local.yml exec db pg_isready -U "${DB_USER}" &>/dev/null; then
        echo -e "${GREEN}Database is ready!${NC}"
        break
    fi
    echo -n "."
    sleep 1
    
    if [ $i -eq 30 ]; then
        echo -e "\n${RED}Database did not initialize in time. Please check for errors:${NC}"
        docker compose -f docker-compose.local.yml logs db
        exit 1
    fi
done

# Create the predictions table
echo -e "${YELLOW}Ensuring database is set up...${NC}"
docker compose -f docker-compose.local.yml exec db psql -U "${DB_USER}" -d "${DB_NAME}" -c "
    CREATE TABLE IF NOT EXISTS predictions (
        id SERIAL PRIMARY KEY,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        predicted_digit INTEGER NOT NULL,
        true_label INTEGER,
        confidence FLOAT NOT NULL
    );" > /dev/null 2>&1

# Show the URL and open browser
echo -e "\n${GREEN}App running at http://localhost:${APP_PORT}${NC}"
echo -e "${YELLOW}Opening browser...${NC}"
open "http://localhost:${APP_PORT}"

# Show helpful information
echo -e "\n${YELLOW}Helpful commands:${NC}"
echo -e "  ${GREEN}docker compose -f docker-compose.local.yml logs -f web${NC}  - View application logs"
echo -e "  ${GREEN}docker compose -f docker-compose.local.yml exec db psql -U ${DB_USER} -d ${DB_NAME}${NC} - Connect to database"
echo -e "  ${GREEN}docker compose -f docker-compose.local.yml down -v${NC} - Stop and clean up all resources"