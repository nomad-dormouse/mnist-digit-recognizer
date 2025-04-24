#!/bin/bash
# DEPLOYMENT SCRIPT FOR MNIST DIGIT RECOGNISER

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
        echo "Model training/verification failed"
        exit 1
fi
echo "Model training/verification completed successfully"

# Now start the remaining services
echo -e "${BLUE}Starting database and web application services...${NC}"
docker-compose up -d --build ${DB_SERVICE_NAME} ${WEB_SERVICE_NAME}

# Wait for database to be ready
echo -e "${BLUE}Waiting for database to be ready...${NC}"
for attempt in {1..10}; do
    if docker exec "${DB_CONTAINER_NAME}" pg_isready -U "${DB_USER}" -d "${DB_NAME}" > /dev/null 2>&1; then
        echo -e "\n${GREEN}Database is ready${NC}"
        break
    fi
    echo -n "."
    sleep 1
    if [[ $attempt -eq 10 ]]; then
        echo -e "${RED}Database did not become ready in time${NC}"
        exit 1
    fi
done

# Verify web service is running
echo -e "${BLUE}Verifying web service...${NC}"
if ! docker-compose ps ${WEB_SERVICE_NAME} | grep -q "Up"; then
    echo -e "${RED}Web service failed to start'${NC}"
    exit 1
fi
echo -e "${GREEN}Web service is running${NC}"

# Remove all unused containers, images, and volumes
echo -e "${BLUE}Removing all unused containers, images, and volumes...${NC}"
docker system prune -a -f

# Set the host to localhost if running locally, or the remote host if running remotely
HOST="localhost"
if [[ "$1" == "remotely" ]]; then
    HOST=${REMOTE_HOST}
fi

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${YELLOW}The web application is available at: http://${HOST}:${WEB_PORT}${NC}"