#!/bin/bash

# ================================================================================
# LOCAL DOCKER DEVELOPMENT RUNNER
# ================================================================================
# This script runs the MNIST Digit Recognizer app locally using Docker.
# 
# Usage:
#   ./local/run_locally.sh
#
# Requirements:
#   - Docker Desktop running
#   - Trained model file in model/saved_models/mnist_model.pth
#
# Notes:
#   - All components (app and database) run in Docker containers
#   - Data persists between runs in a Docker volume
#   - The web interface is available at http://localhost:8501
#   - To view database contents, use: ./local/view_local_db.sh
# ================================================================================

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Load environment variables
source "${PROJECT_ROOT}/.env"

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
docker rm -f "${WEB_CONTAINER_NAME}" 2>/dev/null || true
docker rm -f "${DB_CONTAINER_NAME}" 2>/dev/null || true
docker network rm "${NETWORK_NAME}" 2>/dev/null || true

# Create a named volume for database persistence
echo -e "${YELLOW}Setting up persistent storage...${NC}"
docker volume inspect "${DB_VOLUME_NAME}" >/dev/null 2>&1 || docker volume create "${DB_VOLUME_NAME}"

# Create network for the containers
docker network create "${NETWORK_NAME}"

# Start database container
echo -e "${YELLOW}Starting database container...${NC}"
docker run -d --name "${DB_CONTAINER_NAME}" \
    --network "${NETWORK_NAME}" \
    -p "${DB_PORT}:${DB_PORT}" \
    -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
    -e POSTGRES_USER="${POSTGRES_USER}" \
    -e POSTGRES_DB="${POSTGRES_DB}" \
    -e POSTGRES_INITDB_ARGS="${POSTGRES_INITDB_ARGS}" \
    -e PGDATA="${PGDATA}" \
    -v "${DB_VOLUME_NAME}:/var/lib/postgresql/data" \
    postgres:13

# Wait for database to be ready
echo -e "${YELLOW}Waiting for database to initialize...${NC}"
for i in {1..20}; do
    if docker exec "${DB_CONTAINER_NAME}" pg_isready -U "${DB_USER}" &>/dev/null; then
        echo -e "${GREEN}Database is ready!${NC}"
        break
    fi
    echo -n "."
    sleep 1
    
    if [ $i -eq 20 ]; then
        echo -e "\n${RED}Database did not initialize in time. Please check for errors.${NC}"
        exit 1
    fi
done

# Create the predictions table
echo -e "${YELLOW}Ensuring database is set up...${NC}"
docker exec "${DB_CONTAINER_NAME}" psql -U "${DB_USER}" -d "${DB_NAME}" -c "
    CREATE TABLE IF NOT EXISTS predictions (
        id SERIAL PRIMARY KEY,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        predicted_digit INTEGER NOT NULL,
        true_label INTEGER,
        confidence FLOAT NOT NULL
    );" > /dev/null 2>&1

# Build and start the web container
echo -e "${YELLOW}Building and starting web container...${NC}"
docker build -t mnist-app-local -f local/Dockerfile.local .
docker run -d --name "${WEB_CONTAINER_NAME}" \
    --network "${NETWORK_NAME}" \
    -p "${APP_PORT}:${APP_PORT}" \
    -v "${PROJECT_ROOT}/model/saved_models:/app/model/saved_models:ro" \
    -e DB_HOST="${DB_HOST}" \
    -e DB_PORT="${DB_PORT}" \
    -e DB_NAME="${DB_NAME}" \
    -e DB_USER="${DB_USER}" \
    -e DB_PASSWORD="${DB_PASSWORD}" \
    -e MODEL_PATH="${MODEL_PATH}" \
    mnist-app-local

# Show the URL and open browser
echo -e "\n${GREEN}App running at http://localhost:${APP_PORT}${NC}"
echo -e "${YELLOW}Opening browser...${NC}"
open "http://localhost:${APP_PORT}"

# Show helpful information
echo -e "\n${YELLOW}Helpful commands:${NC}"
echo -e "  ${GREEN}docker logs -f ${WEB_CONTAINER_NAME}${NC}  - View application logs"
echo -e "  ${GREEN}docker exec -it ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME}${NC} - Connect to database"