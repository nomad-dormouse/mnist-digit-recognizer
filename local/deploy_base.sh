#!/bin/bash
# Base deployment script for MNIST Digit Recognizer (works for both local/remote)

set -e  # Exit on error

# Default configuration
ENV_MODE="development"
COMPOSE_FILE="docker-compose.yml"
DB_INIT=true
LOGS=false
ACTION="up"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Help function
show_help() {
    echo -e "${YELLOW}Usage:${NC} $0 [options] [action]"
    echo -e "${GREEN}Actions:${NC} up, down, restart, logs, status (default: up)"
    echo -e "${GREEN}Options:${NC}"
    echo "  -h, --help          Show help"
    echo "  -e, --env ENV       Set environment (development/production)"
    echo "  -f, --file FILE     Use specific docker-compose file"
    echo "  --no-db-init        Skip database initialization"
    echo "  --logs              Show logs after startup"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) show_help; exit 0 ;;
        -e|--env) ENV_MODE="$2"; shift 2 ;;
        -f|--file) COMPOSE_FILE="$2"; shift 2 ;;
        --no-db-init) DB_INIT=false; shift ;;
        --logs) LOGS=true; shift ;;
        up|down|restart|logs|status) ACTION="$1"; shift ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; show_help; exit 1 ;;
    esac
done

# Set environment based on mode
if [[ "$ENV_MODE" == "production" ]]; then
    export IS_DEVELOPMENT=false
    echo -e "${YELLOW}Running in PRODUCTION mode${NC}"
else
    export IS_DEVELOPMENT=true
    echo -e "${YELLOW}Running in DEVELOPMENT mode${NC}"
fi

# Load environment variables
if [[ -f ".env" ]]; then
    source ".env"
fi

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

# Set container names
DB_CONTAINER="${DB_CONTAINER_NAME:-mnist-digit-recognizer-db}"
WEB_CONTAINER="${WEB_CONTAINER_NAME:-mnist-digit-recognizer-web}"

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
    
    while ! docker exec $DB_CONTAINER pg_isready -U postgres -h localhost > /dev/null 2>&1; do
        attempts=$((attempts+1))
        if [[ $attempts -ge 30 ]]; then
            echo -e "${RED}Database did not become ready in time.${NC}"
            return 1
        fi
        echo -n "."
        sleep 1
    done
    echo -e "\n${GREEN}Database is ready!${NC}"
    return 0
}

# Initialize database
init_database() {
    wait_for_db
    
    if ! docker exec $DB_CONTAINER psql -U postgres -d ${DB_NAME:-mnist_db} -c "\dt predictions" 2>/dev/null | grep -q "predictions"; then
        echo -e "${YELLOW}Creating predictions table...${NC}"
        docker exec $DB_CONTAINER psql -U postgres -d ${DB_NAME:-mnist_db} -c "
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

# Perform action
case "$ACTION" in
    up)
        echo -e "${BLUE}Starting containers...${NC}"
        docker-compose -f $COMPOSE_FILE up -d
        
        sleep 3
        check_container $WEB_CONTAINER
        check_container $DB_CONTAINER
        
        if [[ "$DB_INIT" == true ]]; then
            init_database
        fi
        
        echo -e "${GREEN}Application is running at${NC} ${BLUE}http://localhost:${PORT:-8501}${NC}"
        
        if [[ "$LOGS" == true ]]; then
            docker-compose -f $COMPOSE_FILE logs -f
        fi
        ;;
        
    down)
        echo -e "${BLUE}Stopping containers...${NC}"
        docker-compose -f $COMPOSE_FILE down
        echo -e "${GREEN}Containers stopped.${NC}"
        ;;
        
    restart)
        echo -e "${BLUE}Restarting containers...${NC}"
        docker-compose -f $COMPOSE_FILE restart
        
        sleep 3
        check_container $WEB_CONTAINER
        check_container $DB_CONTAINER
        
        echo -e "${GREEN}Containers restarted.${NC}"
        
        if [[ "$LOGS" == true ]]; then
            docker-compose -f $COMPOSE_FILE logs -f
        fi
        ;;
        
    logs)
        docker-compose -f $COMPOSE_FILE logs -f
        ;;
        
    status)
        echo -e "${BLUE}Container status:${NC}"
        docker-compose -f $COMPOSE_FILE ps
        
        echo -e "\n${BLUE}Container health:${NC}"
        check_container $WEB_CONTAINER
        check_container $DB_CONTAINER
        ;;
        
    *)
        echo -e "${RED}Unknown action: $ACTION${NC}"
        show_help
        exit 1
        ;;
esac 