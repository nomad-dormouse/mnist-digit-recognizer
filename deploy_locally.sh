#!/bin/bash
# DEPLOYMENT SCRIPT FOR MNIST DIGIT RECOGNISER

echo -e "${BLUE}Running local deployment script ${LOCAL_DEPLOYMENT_SCRIPT}...${NC}"

# Set error handling
set -e
trap 'echo -e "${RED}Script ${LOCAL_DEPLOYMENT_SCRIPT} terminated${NC}"; exit 1' ERR

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
        HOST="localhost"
        open -a Docker
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        echo -e "${BLUE}Detected Linux. Attempting to start Docker service with systemd...${NC}"
        HOST=${REMOTE_HOST}
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
    echo -e "${GREEN}Docker started successfully${NC}"
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
    echo -e "${BLUE}Waiting for database...${NC}"
    local attempts=0
    local max_attempts=10

    # Check if the database container is running and PostgreSQL is ready
    while ! docker ps --format '{{.Status}}' --filter "name=${DB_CONTAINER_NAME}" | grep -q "Up" || \
          ! docker exec ${DB_CONTAINER_NAME} pg_isready -U ${DB_USER} -d ${DB_NAME} -h localhost || \
          ! docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c '\l' >/dev/null 2>&1; do
        attempts=$((attempts+1))
        if [[ $attempts -ge $max_attempts ]]; then
            echo -e "${RED}Database is not ready. Checking logs:${NC}"
            docker logs ${DB_CONTAINER_NAME}
            return 1
        fi
        echo -n "."
        sleep 1
    done

    echo -e "${GREEN}Database is ready${NC}"
    return 0
}

# Initialise database
initialise_database() {
    echo -e "${BLUE}Initialising database...${NC}"
    docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "
        CREATE TABLE IF NOT EXISTS predictions (
            id SERIAL PRIMARY KEY,
            timestamp TIMESTAMP NOT NULL,
            predicted_digit INTEGER NOT NULL,
            true_label INTEGER,
            confidence FLOAT NOT NULL
        );" 2>/dev/null && echo -e "${GREEN}Database initialised successfully${NC}" || echo -e "${RED}Database initialisation failed${NC}"
}

# Main execution

# Change to script directory which is project root
cd "$(dirname "${BASH_SOURCE[0]}")"

# Load environment variables
if [[ -f ".env" ]]; then
    echo -e "\n${BLUE}Loading environment variables from .env...${NC}"
    source ".env"
else
    echo -e "${RED}.env file not found. Required environment variables cannot be loaded${NC}"
    exit 1
fi

# Ensure Docker is running
echo -e "\n${BLUE}Ensuring Docker is running...${NC}"
if ! check_docker_running; then
    if ! start_docker; then
        echo -e "${RED}Docker failed to start${NC}"
        exit 1
    fi
fi

# Stopping, building and starting containers
echo -e "\n${BLUE}Stopping containers if running...${NC}"
docker stop ${WEB_CONTAINER_NAME} ${DB_CONTAINER_NAME} 2>/dev/null || true

echo -e "\n${BLUE}Removing containers...${NC}"
docker rm ${WEB_CONTAINER_NAME} ${DB_CONTAINER_NAME} 2>/dev/null || true

echo -e "\n${BLUE}Building containers images...${NC}"
docker-compose build --no-cache || { echo -e "${RED}Failed to build container images${NC}"; exit 1; }

echo -e "\n${BLUE}Starting containers...${NC}"
docker-compose up -d || { echo -e "${RED}Failed to start containers${NC}"; exit 1; }
sleep 3
check_container ${WEB_CONTAINER_NAME} || { echo -e "${RED}Web application container failed to start properly${NC}"; exit 1; }
check_container ${DB_CONTAINER_NAME} || { echo -e "${RED}Database container failed to start properly${NC}"; exit 1; }

# Ensure database is initialised
echo -e "\n${BLUE}Ensuring database with predictions table exists...${NC}"
wait_for_db
if ! docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "\dt predictions" 2>/dev/null | grep -q "predictions"; then
    echo -e "${NC}Predictions table not found${NC}"
    init_database
else
    echo -e "${GREEN}Predictions table already exists${NC}"
fi

# Defining host
if [[ "$OSTYPE" == "darwin"* ]]; then
    HOST="localhost"
else
    HOST=${REMOTE_HOST}
fi
echo -e "\n${YELLOW}To view the application, visit: http://$HOST:${APP_PORT}${NC}\n"