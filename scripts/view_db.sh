#!/bin/bash

# Default configuration
LIMIT=20  # Default number of records to show
MODE="container"  # Default mode: container or local

# Remote server settings
REMOTE_USER="root"
REMOTE_HOST="37.27.197.79"
REMOTE_DIR="/root/mnist-digit-recognizer"
SSH_KEY="~/.ssh/hatzner_key"
WEB_CONTAINER_NAME="mnist-digit-recognizer-web-1"
DB_CONTAINER_NAME="mnist-digit-recognizer-db-1" 

# Database settings
DB_NAME="mnist_db"
DB_USER="postgres"
DB_PASSWORD="postgres"
DB_HOST="localhost"
DB_PORT="5432"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -l|--local) MODE="local" ;;
        -n|--limit) LIMIT="$2"; shift ;;
        --limit=*) LIMIT="${1#*=}" ;;
        -a|--all) LIMIT="ALL" ;;
        -h|--help) 
            echo -e "${YELLOW}Usage:${NC}"
            echo -e "  ./scripts/view_db.sh [options]"
            echo -e "\n${YELLOW}Options:${NC}"
            echo -e "  -l, --local         View local Docker container database"
            echo -e "  (default)           View server container database"
            echo -e "  -n, --limit=NUMBER  Limit the number of records to show (default: 20)"
            echo -e "  -a, --all           Show all records"
            echo -e "  -h, --help          Show this help message"
            echo -e "\n${YELLOW}Examples:${NC}"
            echo -e "  ./scripts/view_db.sh                # View server container database"
            echo -e "  ./scripts/view_db.sh -l             # View local Docker container database"
            echo -e "  ./scripts/view_db.sh -n 50          # View with 50 records"
            exit 0 
            ;;
        *) echo -e "${RED}Unknown parameter: $1${NC}"; exit 1 ;;
    esac
    shift
done

# Configure database connection based on mode
if [ "$MODE" = "local" ]; then
    MODE_DESC="local Docker container database"
    
    # Define query functions for local Docker container mode
    execute_query() {
        docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "$1"
    }
    query_value() {
        docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -tAc "$1"
    }
    
    # Check connection
    if ! docker ps | grep ${DB_CONTAINER_NAME} &> /dev/null; then
        echo -e "${RED}Error: Local Docker container ${DB_CONTAINER_NAME} is not running!${NC}"
        exit 1
    fi
else
    MODE_DESC="server container database"
    
    # Define query functions for remote container mode
    execute_query() {
        ssh -i ${SSH_KEY} ${REMOTE_USER}@${REMOTE_HOST} "docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c \"$1\""
    }
    query_value() {
        ssh -i ${SSH_KEY} ${REMOTE_USER}@${REMOTE_HOST} "docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -tAc \"$1\""
    }
    
    # Check connection
    if ! ssh -i ${SSH_KEY} ${REMOTE_USER}@${REMOTE_HOST} "docker ps | grep ${DB_CONTAINER_NAME}" &> /dev/null; then
        echo -e "${RED}Error: Cannot connect to database container on server!${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}Viewing ${MODE_DESC} (limit: $LIMIT)...${NC}"

# Get basic statistics
TOTAL_RECORDS=$(query_value "SELECT COUNT(*) FROM predictions;")
LABELED_RECORDS=$(query_value "SELECT COUNT(*) FROM predictions WHERE true_label IS NOT NULL;")
CORRECT_PREDICTIONS=$(query_value "SELECT COUNT(*) FROM predictions WHERE predicted_digit = true_label;")

# Display basic statistics
echo -e "${GREEN}Total records: ${TOTAL_RECORDS} | Labeled records: ${LABELED_RECORDS} | Correct predictions: ${CORRECT_PREDICTIONS}${NC}"

# Calculate and display accuracy
if [ "$LABELED_RECORDS" != "0" ] && command -v bc &> /dev/null; then
    ACCURACY=$(echo "scale=2; ($CORRECT_PREDICTIONS / $LABELED_RECORDS) * 100" | bc)
    echo -e "${BLUE}Overall accuracy: ${ACCURACY}%${NC}"
fi

# Display recent predictions
echo -e "\n${YELLOW}Recent predictions:${NC}"
execute_query "
    SELECT 
        id, timestamp, predicted_digit, true_label, confidence 
    FROM predictions 
    ORDER BY timestamp DESC 
    LIMIT $LIMIT;"

# Display digit statistics
echo -e "\n${YELLOW}Predictions by digit:${NC}"
execute_query "
    SELECT 
        predicted_digit, 
        COUNT(*) as count,
        (AVG(confidence) * 100)::numeric(10,2) as avg_confidence_pct
    FROM predictions 
    GROUP BY predicted_digit 
    ORDER BY predicted_digit;"

# Display accuracy by digit
echo -e "\n${YELLOW}Accuracy by digit:${NC}"
execute_query "
    WITH stats AS (
        SELECT 
            true_label,
            COUNT(*) as total,
            SUM(CASE WHEN predicted_digit = true_label THEN 1 ELSE 0 END) as correct
        FROM predictions
        WHERE true_label IS NOT NULL
        GROUP BY true_label
    )
    SELECT 
        true_label as digit,
        total as attempts,
        correct as correct_predictions,
        (correct::float / total * 100)::numeric(10,2) as accuracy_pct
    FROM stats
    ORDER BY true_label;"

# Show top misclassifications if we have labeled data
if [ "$LABELED_RECORDS" -gt 5 ]; then
    echo -e "\n${YELLOW}Top misclassifications:${NC}"
    execute_query "
        SELECT 
            true_label as actual_digit,
            predicted_digit as predicted_as,
            COUNT(*) as count
        FROM predictions
        WHERE true_label IS NOT NULL
          AND true_label != predicted_digit
        GROUP BY true_label, predicted_digit
        ORDER BY count DESC
        LIMIT 5;"
fi

# Display connection info
echo -e "\n${GREEN}Connected to ${MODE_DESC}${NC}" 