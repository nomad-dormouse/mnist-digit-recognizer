#!/bin/bash

# LOCAL DATABASE VIEWER
# This script views the local Docker containerized database.
# 
# Usage:
#   ./local/helpers/view_local_db.sh           # Default 20 records
#   ./local/helpers/view_local_db.sh 50        # Show 50 records
#   ./local/helpers/view_local_db.sh all       # Show all records

# INITIALIZATION
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
PROJECT_ROOT="$(dirname "${PARENT_DIR}")"

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ENVIRONMENT VARIABLES
# Load environment variables if they exist
if [ -f "${PROJECT_ROOT}/.env" ]; then
    source "${PROJECT_ROOT}/.env"
fi

# Database settings (use environment variables or defaults)
DB_CONTAINER="${DB_CONTAINER_NAME:-mnist-digit-recognizer-db}"
DB_NAME="${DB_NAME:-mnist_db}"
DB_USER="${DB_USER:-postgres}"

# Parse command line arguments
LIMIT=20  # Default number of records to show

if [[ "$1" == "all" ]]; then
    LIMIT="ALL"
elif [[ "$1" =~ ^[0-9]+$ ]]; then
    LIMIT="$1"
fi

# PREREQUISITES CHECK
# Check if Docker is running
if ! docker ps &>/dev/null; then
    echo -e "${RED}Error: Docker is not running. Start Docker Desktop first.${NC}"
    exit 1
fi

# Check if database container is running
if ! docker ps -q -f name="^${DB_CONTAINER}$" &>/dev/null; then
    echo -e "${RED}Error: Database container '${DB_CONTAINER}' is not running.${NC}"
    echo -e "Run ${YELLOW}./local/run_locally.sh${NC} to start the application."
    exit 1
fi

echo -e "${YELLOW}Viewing local database records (limit: $LIMIT)...${NC}"

# DATABASE QUERIES
# Query functions
docker_db_query() {
    docker exec ${DB_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -c "$1"
}

docker_db_value() {
    docker exec ${DB_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -tAc "$1"
}

# Check if predictions table exists
if ! docker exec ${DB_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -c "\dt predictions" | grep -q "predictions"; then
    echo -e "${RED}Error: Table 'predictions' does not exist.${NC}"
    echo -e "Run ${YELLOW}./local/run_locally.sh${NC} to initialize the database."
    exit 1
fi

# ANALYTICS
# Get statistics
TOTAL_RECORDS=$(docker_db_value "SELECT COUNT(*) FROM predictions;")
LABELED_RECORDS=$(docker_db_value "SELECT COUNT(*) FROM predictions WHERE true_label IS NOT NULL;")
CORRECT_PREDICTIONS=$(docker_db_value "SELECT COUNT(*) FROM predictions WHERE predicted_digit = true_label;")

# Display basic statistics
echo -e "${GREEN}Total records: ${TOTAL_RECORDS} | Labeled records: ${LABELED_RECORDS} | Correct predictions: ${CORRECT_PREDICTIONS}${NC}"

# Calculate and display accuracy
if [ "$LABELED_RECORDS" != "0" ]; then
    ACCURACY=$(echo "scale=2; ($CORRECT_PREDICTIONS / $LABELED_RECORDS) * 100" | bc)
    echo -e "${BLUE}Overall accuracy: ${ACCURACY}%${NC}"
fi

# DATA VISUALIZATION
# Display recent predictions
echo -e "\n${YELLOW}Recent predictions:${NC}"
docker_db_query "
    SELECT 
        id, timestamp, predicted_digit, true_label, confidence 
    FROM predictions 
    ORDER BY timestamp DESC 
    LIMIT $LIMIT;"

# Display digit statistics
echo -e "\n${YELLOW}Predictions by digit:${NC}"
docker_db_query "
    SELECT 
        predicted_digit, 
        COUNT(*) as count,
        (AVG(confidence) * 100)::numeric(10,2) as avg_confidence_pct
    FROM predictions 
    GROUP BY predicted_digit 
    ORDER BY predicted_digit;"

# Display accuracy by digit if we have labeled data
if [ "$LABELED_RECORDS" -gt 0 ]; then
    echo -e "\n${YELLOW}Accuracy by digit:${NC}"
    docker_db_query "
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
fi

# USER INFORMATION
echo -e "\n${GREEN}Local database query complete.${NC}"
echo -e "To view more or fewer records, use: ${YELLOW}./local/helpers/view_local_db.sh [limit|all]${NC}"
echo -e "To view server database, use: ${YELLOW}./remote/helpers/view_db.sh${NC}" 