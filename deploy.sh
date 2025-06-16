#!/bin/bash

# Set error handling
set -e
trap 'echo -e "${RED}Deployment script terminated with error${NC}"; exit 1' ERR

# Change to script directory which is project root
cd "$(dirname "${BASH_SOURCE[0]}")"

# Load environment variables
if [[ -f ".env" ]]; then
    source ".env"
else
    echo "ERROR: .env file not found"
    exit 1
fi

echo -e "${BLUE}Starting deployment for MNIST Digit Recogniser...${NC}"

# Ensure Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${BLUE}Docker is not running. Attempting to start Docker...${NC}"
    # Different commands based on OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open -a Docker || { echo -e "${RED}Failed to launch Docker Desktop${NC}"; exit 1; }
    elif command -v systemctl > /dev/null; then
        sudo systemctl start docker || { echo -e "${RED}Failed to start Docker service${NC}"; exit 1; }
    else
        echo -e "${RED}Unsupported OS. Please start Docker manually.${NC}"
        exit 1
    fi
    echo -e "${BLUE}Waiting for Docker to start...${NC}"
    for i in {1..30}; do
        if docker info > /dev/null 2>&1; then
            echo -e "${GREEN}Docker started successfully${NC}"
            break
        fi
        echo -n "."
        sleep 2
    done
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}Docker failed to start. Please start it manually${NC}"
        exit 1
    fi
fi

# Disk space cleanup
echo -e "${BLUE}Checking disk space before cleanup...${NC}"
df -h
echo -e "${BLUE}Cleaning up existing project containers...${NC}"
docker-compose down --remove-orphans 2>/dev/null || true
docker images --format "table {{.Repository}}:{{.Tag}}" | grep -E "mnist|digit" | grep -v REPOSITORY | while read image; do
    echo "Removing image: $image"
    docker rmi "$image" 2>/dev/null || true
done
echo -e "${BLUE}Performing targeted Docker cleanup...${NC}"
docker image prune -f 2>/dev/null || true
docker builder prune -f 2>/dev/null || true
docker volume prune -f 2>/dev/null || true
echo -e "${BLUE}Disk space after cleanup:${NC}"
df -h

# First, build, run and remove the model training service
echo -e "${BLUE}Building and running model training service...${NC}"
docker-compose build ${MODEL_SERVICE_NAME}
docker-compose run --rm ${MODEL_SERVICE_NAME}
if [ $? -ne 0 ]; then
    echo -e "${RED}Model training/verification failed${NC}"
    exit 1
fi
echo -e "${GREEN}Model training/verification completed successfully${NC}"

# Now build and start the remaining services
echo -e "${BLUE}Building and starting database, web server and web application services...${NC}"
docker-compose up -d --build ${DB_SERVICE_NAME} ${WEBSERVER_SERVICE_NAME} ${WEBAPP_SERVICE_NAME}

# Wait for database to be ready
echo -e "${BLUE}Waiting for database to be ready...${NC}"
for attempt in {1..10}; do
    if docker exec "${DB_CONTAINER_NAME}" pg_isready -U "${DB_USER}" -d "${DB_NAME}" > /dev/null 2>&1; then
        echo -e "${GREEN}Database is ready${NC}"
        break
    fi
    echo -n "."
    sleep 1
    if [[ $attempt -eq 10 ]]; then
        echo -e "${RED}Database did not become ready in time${NC}"
        exit 1
    fi
done

# Check web server container health status
echo -e "${BLUE}Checking web server container health status...${NC}"
for attempt in {1..10}; do
    if curl -s "http://localhost:${WEBSERVER_PORT}/health" | grep -q "healthy"; then
        echo -e "\n${GREEN}Web server container health check passed${NC}"
        break
    fi
    echo -n "."
    sleep 1
    if [[ $attempt -eq 10 ]]; then
        echo -e "\n${RED}Web server container health check failed${NC}"
        exit 1
    fi
done

echo -e "${BLUE}Waiting for web application service to be responsive...${NC}"
for attempt in {1..30}; do
    if curl -s --max-time 5 "http://localhost:${WEBAPP_PORT}" > /dev/null 2>&1; then
        echo -e "\n${GREEN}Web application service is responsive on port ${WEBAPP_PORT}${NC}"
        break
    fi
    echo -n "."
    sleep 2
    if [[ $attempt -eq 30 ]]; then
        echo -e "\n${RED}Web application service did not respond in time${NC}"
        echo -e "${YELLOW}Checking container logs:${NC}"
        docker-compose logs ${WEBAPP_SERVICE_NAME}
        exit 1
    fi
done

# Set the host to localhost if running locally, or the remote host if running remotely
HOST="localhost"
if [[ "$1" == "remotely" ]]; then
    HOST=${REMOTE_HOST:-localhost}
fi

echo -e "${YELLOW}The web application is available at: http://${HOST}:${WEBAPP_PORT}${NC}"