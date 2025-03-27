#!/bin/bash

# ================================================================================
# SERVER DATABASE VIEWER
# ================================================================================
# This script is designed to run on the remote server.
# 
# To run from your local machine:
#   ssh -i ~/.ssh/hatzner_key root@37.27.197.79 "cd /root/mnist-digit-recognizer && ./scripts/view_db.sh [limit|all]"
#
# Examples:
#   ssh -i ~/.ssh/hatzner_key root@37.27.197.79 "cd /root/mnist-digit-recognizer && ./scripts/view_db.sh"        # Default 20 records
#   ssh -i ~/.ssh/hatzner_key root@37.27.197.79 "cd /root/mnist-digit-recognizer && ./scripts/view_db.sh 50"     # Show 50 records
#   ssh -i ~/.ssh/hatzner_key root@37.27.197.79 "cd /root/mnist-digit-recognizer && ./scripts/view_db.sh all"    # Show all records
# ================================================================================

# Database settings
DB_CONTAINER="mnist-digit-recognizer-db-1"
DB_NAME="mnist_db"
DB_USER="postgres"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
LIMIT=20  # Default number of records to show

if [[ "$1" == "all" ]]; then
    LIMIT="ALL"
elif [[ "$1" =~ ^[0-9]+$ ]]; then
    LIMIT="$1"
fi

echo -e "${YELLOW}Viewing database records (limit: $LIMIT)...${NC}"

# Check if the database container is running
echo -e "${YELLOW}Checking Docker container status...${NC}"
if ! docker ps | grep -q ${DB_CONTAINER}; then
    echo -e "${YELLOW}Database container not running. Showing all containers:${NC}"
    docker ps
    exit 1
fi

echo -e "${YELLOW}Database container found. Retrieving records...${NC}"

# Run queries in the database container
TOTAL_RECORDS=$(docker exec ${DB_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -tAc "SELECT COUNT(*) FROM predictions;")
LABELED_RECORDS=$(docker exec ${DB_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -tAc "SELECT COUNT(*) FROM predictions WHERE true_label IS NOT NULL;")
CORRECT_PREDICTIONS=$(docker exec ${DB_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -tAc "SELECT COUNT(*) FROM predictions WHERE predicted_digit = true_label;")

# Display basic statistics
echo -e "${GREEN}Total records: ${TOTAL_RECORDS} | Labeled records: ${LABELED_RECORDS} | Correct predictions: ${CORRECT_PREDICTIONS}${NC}"

# Calculate and display accuracy
if [ "$LABELED_RECORDS" != "0" ]; then
    ACCURACY=$(echo "scale=2; ($CORRECT_PREDICTIONS / $LABELED_RECORDS) * 100" | bc)
    echo -e "${BLUE}Overall accuracy: ${ACCURACY}%${NC}"
fi

# Display recent predictions
echo -e "\n${YELLOW}Recent predictions:${NC}"
docker exec ${DB_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -c "
    SELECT 
        id, timestamp, predicted_digit, true_label, confidence 
    FROM predictions 
    ORDER BY timestamp DESC 
    LIMIT $LIMIT;"

# Display digit statistics
echo -e "\n${YELLOW}Predictions by digit:${NC}"
docker exec ${DB_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -c "
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
    docker exec ${DB_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -c "
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

echo -e "\n${GREEN}Database query complete.${NC}"
echo -e "To view more or fewer records, use: ./scripts/view_db.sh [limit|all]" 