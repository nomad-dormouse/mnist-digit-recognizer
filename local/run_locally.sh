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
#
# Notes:
#   - All components (app and database) run in Docker containers
#   - Data persists between runs in a Docker volume
#   - The web interface is available at http://localhost:8501
#   - To view database contents, use: ./local/view_local_db.sh
# ================================================================================

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

# Clean up existing resources
echo -e "${YELLOW}Cleaning up existing resources...${NC}"
docker rm -f mnist-digit-recognizer-web-1 2>/dev/null || true
docker rm -f mnist-digit-recognizer-db-1 2>/dev/null || true
docker network rm mnist-network 2>/dev/null || true

# Create a named volume for database persistence
echo -e "${YELLOW}Setting up persistent storage...${NC}"
docker volume inspect mnist-postgres-data >/dev/null 2>&1 || docker volume create mnist-postgres-data

# Create network for the containers
docker network create mnist-network

# Start database container
echo -e "${YELLOW}Starting database container...${NC}"
docker run -d --name mnist-digit-recognizer-db-1 \
    --network mnist-network \
    -p 5432:5432 \
    -e POSTGRES_PASSWORD=postgres \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_DB=mnist_db \
    -v mnist-postgres-data:/var/lib/postgresql/data \
    postgres:13

# Wait for database to be ready
echo -e "${YELLOW}Waiting for database to initialize...${NC}"
for i in {1..20}; do
    if docker exec mnist-digit-recognizer-db-1 pg_isready -U postgres &>/dev/null; then
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
docker exec mnist-digit-recognizer-db-1 psql -U postgres -d mnist_db -c "
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
docker run -d --name mnist-digit-recognizer-web-1 \
    --network mnist-network \
    -p 8501:8501 \
    -v "$(pwd)/model/saved_models:/app/model/saved_models:ro" \
    mnist-app-local

# Show the URL and open browser
echo -e "\n${GREEN}App running at http://localhost:8501${NC}"
echo -e "${YELLOW}Opening browser...${NC}"
open "http://localhost:8501"

# Show helpful information
echo -e "\n${YELLOW}Helpful commands:${NC}"
echo -e "  ${GREEN}docker logs -f mnist-digit-recognizer-web-1${NC}  - View application logs"
echo -e "  ${GREEN}docker exec -it mnist-digit-recognizer-db-1 psql -U postgres -d mnist_db${NC} - Connect to database"