#!/bin/bash
# DEPLOYMENT SCRIPT FOR MNIST DIGIT RECOGNISER

# Check if Docker is running
check_docker_running() {
    if docker info > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Try to start Docker
start_docker() {
    echo -e "${BLUE}Docker is not running. Attempting to start Docker...${NC}"
    
    # Different commands based on OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        echo -e "${BLUE}Detected macOS. Starting Docker Desktop...${NC}"
        open -a Docker
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        echo -e "${BLUE}Detected Linux. Attempting to start Docker service with systemd...${NC}"
        sudo systemctl start docker
    else
        # Windows or other OS
        echo -e "${RED}Unsupported OS for auto-starting Docker. Please start Docker manually and try again.${NC}"
        return 1
    fi

    # Wait for Docker to start up to 60 seconds
    local attempts=0
    local max_attempts=60

    while ! check_docker_running; do
        attempts=$((attempts+1))
        if [[ $attempts -ge $max_attempts ]]; then
            echo -e "${RED}Failed to start Docker after $max_attempts seconds. Please check Docker installation and try again.${NC}"
            return 1
        fi
        echo -n "."
        sleep 1
    done
    echo -e "\n${GREEN}Docker started successfully${NC}"
    return 0
}

# Check if container is running
check_container() {
    if docker ps --format '{{.Names}}' | grep -q "^${1}$"; then
        echo -e "${GREEN}$1 is running${NC}"
        return 0
    else
        echo -e "${RED}$1 is not running${NC}"
        return 1
    fi
}

# Wait for database to be ready
wait_for_db() {
    echo -e "\n${BLUE}Waiting for database...${NC}"
    local attempts=0
    local max_attempts=10
    
    # First, wait for container to be running
    while ! docker ps --format '{{.Status}}' --filter "name=${DB_CONTAINER_NAME}" | grep -q "Up"; do
        attempts=$((attempts+1))
        if [[ $attempts -ge $max_attempts ]]; then
            echo -e "${RED}Database container failed to start.${NC}"
            docker logs ${DB_CONTAINER_NAME}
            return 1
        fi
        echo -n "."
        sleep 1
    done
    
    echo -e "${NC}Database container is running. Waiting for PostgreSQL to be ready...${NC}"
    attempts=0
    
    # Then wait for PostgreSQL to be ready
    while ! docker exec ${DB_CONTAINER_NAME} pg_isready -U ${DB_USER} -d ${DB_NAME} -h localhost; do
        attempts=$((attempts+1))
        if [[ $attempts -ge $max_attempts ]]; then
            echo -e "${RED}PostgreSQL failed to become ready. Checking logs:${NC}"
            docker logs ${DB_CONTAINER_NAME}
            return 1
        fi
        sleep 1
    done
    
    # Finally, check if we can actually connect and run a query
    attempts=0
    while ! docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c '\l' >/dev/null 2>&1; do
        attempts=$((attempts+1))
        if [[ $attempts -ge $max_attempts ]]; then
            echo -e "${RED}Could not connect to PostgreSQL. Checking logs:${NC}"
            docker logs ${DB_CONTAINER_NAME}
            return 1
        fi
        sleep 1
    done
    
    echo -e "${GREEN}Database is ready${NC}"
    return 0
}

# Initialize database
init_database() {
    wait_for_db

    echo -e "${BLUE}Ensuring predictions table exists...${NC}"
    if docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "
        CREATE TABLE IF NOT EXISTS predictions (
            id SERIAL PRIMARY KEY,
            timestamp TIMESTAMP NOT NULL,
            predicted_digit INTEGER NOT NULL,
            true_label INTEGER,
            confidence FLOAT NOT NULL
        );" 2>/dev/null; then
        echo -e "${GREEN}Database successfully initialized or already exists${NC}"
    else
        echo -e "${RED}Error initializing database. Checking logs:${NC}"
        docker logs ${DB_CONTAINER_NAME}
    fi
}

# Main execution

# Change to script directory which is project root
cd "$(dirname "${BASH_SOURCE[0]}")"

# Load environment variables
if [[ -f ".env" ]]; then
    echo -e "${BLUE}Loading environment variables from .env...${NC}"
    source ".env"
else
    echo -e "${RED}Error: .env file not found$, so required environment variables cannot be loaded${NC}"
    echo -e "${RED}Terminating script${NC}"
    exit 1
fi

# Ensure Docker is running
echo -e "\n${BLUE}Ensuring Docker is running...${NC}"
if ! check_docker_running; then
    if ! start_docker; then
        echo -e "${RED}Terminating script${NC}"
        exit 1
    fi
fi

echo -e "\n${BLUE}Rebuilding and starting containers...${NC}"

# Stop only the specific containers we'll be rebuilding
echo -e "\n${BLUE}Stopping application containers if running...${NC}"
docker stop ${WEB_CONTAINER_NAME} ${DB_CONTAINER_NAME} 2>/dev/null || true
docker rm ${WEB_CONTAINER_NAME} ${DB_CONTAINER_NAME} 2>/dev/null || true

# Force rebuild of images without using cache
echo -e "\n${BLUE}Building container images...${NC}"
docker-compose build --no-cache

# Start containers with the fresh builds
echo -e "\n${BLUE}Starting containers...${NC}"
docker-compose up -d

sleep 3
check_container ${WEB_CONTAINER_NAME}
check_container ${DB_CONTAINER_NAME}

init_database

echo -e "\n${GREEN}Containers built and started with preserved data${NC}"
echo -e "\n${YELLOW}To view the application, visit: http://${HOST}:${APP_PORT}${NC}\n" 