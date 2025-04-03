#!/bin/bash
# View records from the local MNIST database
# Usage: ./local/view_local_db.sh [limit|all]

# Get directory paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
PROJECT_ROOT="$(dirname "${PARENT_DIR}")"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Load environment variables
[ -f "${PROJECT_ROOT}/.env" ] && source "${PROJECT_ROOT}/.env"

# Database settings
DB_CONTAINER="${DB_CONTAINER_NAME:-mnist-digit-recognizer-db}"
DB_NAME="${DB_NAME:-mnist_db}"
DB_USER="${DB_USER:-postgres}"

# Set record limit
LIMIT=20
[[ "$1" == "all" ]] && LIMIT="ALL"
[[ "$1" =~ ^[0-9]+$ ]] && LIMIT="$1"

# Check Docker
if ! docker ps &>/dev/null; then
    echo -e "${RED}Error: Docker is not running. Start Docker Desktop first.${NC}"
    exit 1
fi

# Check database container
if ! docker ps -q -f name="^${DB_CONTAINER}$" &>/dev/null; then
    echo -e "${RED}Error: Database container '${DB_CONTAINER}' is not running.${NC}"
    echo -e "Run ${YELLOW}./local/deploy_locally.sh${NC} to start the application."
    exit 1
fi

echo -e "${YELLOW}Viewing local database records (limit: $LIMIT)...${NC}"

# Define query functions
docker_db_query() { docker exec ${DB_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -c "$1"; }
docker_db_value() { docker exec ${DB_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -tAc "$1"; }

# Check predictions table
if ! docker exec ${DB_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -c "\dt predictions" | grep -q "predictions"; then
    echo -e "${RED}Error: Table 'predictions' does not exist.${NC}"
    echo -e "Run ${YELLOW}./local/deploy_locally.sh${NC} to initialize the database."
    exit 1
fi

# Get statistics
TOTAL_RECORDS=$(docker_db_value "SELECT COUNT(*) FROM predictions;")
LABELED_RECORDS=$(docker_db_value "SELECT COUNT(*) FROM predictions WHERE true_label IS NOT NULL;")
CORRECT_PREDICTIONS=$(docker_db_value "SELECT COUNT(*) FROM predictions WHERE predicted_digit = true_label;")

# Display stats
echo -e "${GREEN}Total records: ${TOTAL_RECORDS} | Labeled records: ${LABELED_RECORDS} | Correct predictions: ${CORRECT_PREDICTIONS}${NC}"

# Calculate accuracy
if [ "$LABELED_RECORDS" != "0" ]; then
    ACCURACY=$(echo "scale=2; ($CORRECT_PREDICTIONS / $LABELED_RECORDS) * 100" | bc)
    echo -e "${BLUE}Overall accuracy: ${ACCURACY}%${NC}"
fi

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

# Display accuracy by digit
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

echo -e "\n${GREEN}Local database query complete.${NC}"
echo -e "To view more or fewer records, use: ${YELLOW}./local/view_local_db.sh [limit|all]${NC}" 