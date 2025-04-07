#!/bin/bash
# DEPLOYMENT SCRIPT FOR MNIST DIGIT RECOGNIZER

set -e  # Exit on error

# Default configuration
ENVIRONMENT="local"
ACTION="up"

# Load environment variables
if [[ -f ".env" ]]; then
    source ".env"
fi

# Help function
show_help() {
    echo -e "${YELLOW}Usage:${NC} $0 [environment] [action]"
    echo -e "${GREEN}Environment:${NC}"
    echo "  local     Deploy in local development environment (default)"
    echo "  remote    Deploy in remote production environment"
    echo -e "${GREEN}Actions:${NC}"
    echo "  up        Start containers (default)"
    echo "  down      Stop and remove containers"
    echo "  restart   Restart containers"
    echo "  logs      View logs"
    echo "  status    Check container status"
    echo -e "${GREEN}Examples:${NC}"
    echo "  $0 local up      Start application locally and open browser"
    echo "  $0 remote up     Deploy application to remote server"
    echo "  $0 local down    Stop local containers"
}

# Parse command line arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Process environment argument
if [[ "$1" == "local" || "$1" == "remote" ]]; then
    ENVIRONMENT="$1"
    shift
else
    echo -e "${YELLOW}No environment specified, defaulting to 'local'${NC}"
fi

# Process action argument
if [[ "$1" == "up" || "$1" == "down" || "$1" == "restart" || "$1" == "logs" || "$1" == "status" ]]; then
    ACTION="$1"
    shift
elif [[ -n "$1" ]]; then
    echo -e "${RED}Unknown action: $1${NC}"
    show_help
    exit 1
fi

# Configure environment based on deployment type
if [[ "$ENVIRONMENT" == "remote" ]]; then
    # Production environment settings
    HOST=${REMOTE_HOST}
    echo -e "${YELLOW}Running in REMOTE (production) mode${NC}"
else
    # Local environment settings
    HOST=localhost
    echo -e "${YELLOW}Running in LOCAL (development) mode${NC}"
fi

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

# Check if container is running
check_container() {
    if docker ps --format '{{.Names}}' | grep -q "^${1}$"; then
        echo -e "${GREEN}✓ $1 is running${NC}"
        return 0
    else
        echo -e "${RED}✗ $1 is not running${NC}"
        return 1
    fi
}

# Wait for database to be ready
wait_for_db() {
    echo -e "${BLUE}Waiting for database...${NC}"
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
    
    echo -e "\n${GREEN}Database container is running. Waiting for PostgreSQL to be ready...${NC}"
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
    
    echo -e "${GREEN}Database is ready!${NC}"
    return 0
}

# Initialize database
init_database() {
    wait_for_db
    
    if ! docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "\dt predictions" 2>/dev/null | grep -q "predictions"; then
        echo -e "${YELLOW}Creating predictions table...${NC}"
        docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "
            CREATE TABLE IF NOT EXISTS predictions (
                id SERIAL PRIMARY KEY,
                timestamp TIMESTAMP NOT NULL,
                predicted_digit INTEGER NOT NULL,
                true_label INTEGER,
                confidence FLOAT NOT NULL
            );"
        echo -e "${GREEN}Database initialized.${NC}"
    else
        echo -e "${GREEN}Database already initialized.${NC}"
    fi
}

# Open application in browser
open_browser() {
    local url="http://${HOST}:${APP_PORT}"
    
    # Wait a moment for the application to fully start
    echo -e "${BLUE}Waiting for application to start...${NC}"
    sleep 5
    
    echo -e "${GREEN}Opening application in browser: $url"
    
    # Open browser based on platform
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "$url"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        xdg-open "$url" &>/dev/null
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        start "$url"
    else
        echo -e "${YELLOW}Cannot automatically open browser on this platform. Please visit: $url"
    fi
}

# Perform action
case "$ACTION" in
    up)
        echo -e "${BLUE}Starting containers in ${ENVIRONMENT} environment...${NC}"
        
        # Start the containers with docker-compose
        docker-compose up -d
        
        sleep 3
        check_container ${WEB_CONTAINER_NAME}
        check_container ${DB_CONTAINER_NAME}
        
        init_database
        
        echo -e "${GREEN}Application is running at: http://${HOST}:${APP_PORT}${NC}"
        
        # Open browser for local environment
        if [[ "$ENVIRONMENT" == "local" ]]; then
            open_browser
        fi
        ;;
        
    down)
        echo -e "${BLUE}Stopping containers...${NC}"
        docker-compose down
        echo -e "${GREEN}Containers stopped.${NC}"
        ;;
        
    restart)
        echo -e "${BLUE}Restarting containers...${NC}"
        docker-compose restart
        
        sleep 3
        check_container ${WEB_CONTAINER_NAME}
        check_container ${DB_CONTAINER_NAME}
        
        echo -e "${GREEN}Containers restarted.${NC}"
        
        # Open browser for local environment after restart
        if [[ "$ENVIRONMENT" == "local" ]]; then
            open_browser
        fi
        ;;
        
    logs)
        docker-compose logs -f
        ;;
        
    status)
        echo -e "${BLUE}Container status:${NC}"
        docker-compose ps
        
        echo -e "\n${BLUE}Container health:${NC}"
        check_container ${WEB_CONTAINER_NAME}
        check_container ${DB_CONTAINER_NAME}
        ;;
        
    *)
        echo -e "${RED}Unknown action: $ACTION${NC}"
        show_help
        exit 1
        ;;
esac 