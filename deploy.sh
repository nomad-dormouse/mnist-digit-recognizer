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
        open -a Docker || { echo "Failed to launch Docker Desktop"; exit 1; }
    elif command -v systemctl > /dev/null; then
        sudo systemctl start docker || { echo "Failed to start Docker service"; exit 1; }
    else
        echo "Unsupported OS. Please start Docker manually."
        exit 1
    fi
    # Wait for Docker to start
    for i in {1..15}; do
        if docker info > /dev/null 2>&1; then
            echo -e "${GREEN}Docker started successfully${NC}"
            break
        fi
        sleep 1
    done
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}Docker failed to start. Please start it manually${NC}"
        exit 1
    fi
fi

# Remove all unused containers, images, and volumes
echo -e "${BLUE}Removing all unused containers, images, and volumes...${NC}"
docker system prune -a -f

# First, build and run only the model training service
echo -e "${BLUE}Build a fresh image of model training service, run it and remove it after...${NC}"
docker-compose build ${MODEL_SERVICE_NAME}
docker-compose run --rm ${MODEL_SERVICE_NAME}
if [ $? -ne 0 ]; then
    echo -e "${RED}Model training/verification failed${NC}"
    exit 1
fi
echo -e "${GREEN}Model training/verification completed successfully${NC}"

# Now start the remaining services
echo -e "${BLUE}Starting database, web server and web application services...${NC}"
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

# Verify web application service is running
echo -e "${BLUE}Waiting for web application service to be responsive...${NC}"
for attempt in {1..10}; do
    if curl -s "http://localhost:${WEBAPP_PORT}" > /dev/null; then
        echo -e "\n${GREEN}Web application service is responsive on port ${WEBAPP_PORT}${NC}"
        break
    fi
    echo -n "."
    sleep 1
    if [[ $attempt -eq 10 ]]; then
        echo -e "\n${RED}Web application service did not respond in time${NC}"
        exit 1
    fi
done

# Remove all unused containers, images, and volumes
echo -e "${BLUE}Removing all unused containers, images, and volumes...${NC}"
docker system prune -a -f

# Set the host to localhost if running locally, or the remote host if running remotely
HOST="localhost"
if [[ "$1" == "remotely" ]]; then
    HOST=${REMOTE_HOST}
fi

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${YELLOW}The web application is available at: http://${HOST}:${WEBAPP_PORT}${NC}"