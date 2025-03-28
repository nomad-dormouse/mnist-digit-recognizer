#!/bin/bash

# ================================================================================
# REMOTE SERVER DATABASE VIEWER
# ================================================================================
# This script connects to the remote server and displays database records.
# 
# Usage:
#   ./database/view_db.sh [limit|all]
#
# Examples:
#   ./database/view_db.sh        # Default 20 records
#   ./database/view_db.sh 50     # Show 50 records
#   ./database/view_db.sh all    # Show all records
# ================================================================================

# Configuration
REMOTE_USER="root"
REMOTE_HOST="37.27.197.79"
REMOTE_DIR="/root/mnist-digit-recognizer"
SSH_KEY="${HOME}/.ssh/hetzner_key"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Parse command line arguments
LIMIT="${1:-20}"  # Default to 20 if not specified

# Check if SSH key exists
if [ ! -f "${SSH_KEY}" ]; then
    echo -e "${RED}Error: SSH key not found at ${SSH_KEY}${NC}"
    echo -e "Please ensure your SSH key is correctly set up."
    exit 1
fi

echo -e "${YELLOW}Connecting to ${REMOTE_HOST} to view database records...${NC}"

# SSH into the remote server and run the database viewer
ssh -i ${SSH_KEY} ${REMOTE_USER}@${REMOTE_HOST} << EOF
    set -e
    
    cd ${REMOTE_DIR}
    
    # Database settings
    DB_CONTAINER="mnist-digit-recognizer-db-1"
    DB_NAME="mnist_db"
    DB_USER="postgres"
    
    # Parse limit
    LIMIT="${LIMIT}"
    if [[ "\$LIMIT" == "all" ]]; then
        LIMIT="ALL"
    fi
    
    echo "Viewing database records (limit: \$LIMIT)..."
    
    # Check if the database container is running
    echo "Checking Docker container status..."
    if ! docker ps | grep -q \${DB_CONTAINER}; then
        echo "Database container not running. Showing all containers:"
        docker ps
        exit 1
    fi
    
    echo "Database container found. Retrieving records..."
    
    # Run queries in the database container
    TOTAL_RECORDS=\$(docker exec \${DB_CONTAINER} psql -U \${DB_USER} -d \${DB_NAME} -tAc "SELECT COUNT(*) FROM predictions;")
    LABELED_RECORDS=\$(docker exec \${DB_CONTAINER} psql -U \${DB_USER} -d \${DB_NAME} -tAc "SELECT COUNT(*) FROM predictions WHERE true_label IS NOT NULL;")
    CORRECT_PREDICTIONS=\$(docker exec \${DB_CONTAINER} psql -U \${DB_USER} -d \${DB_NAME} -tAc "SELECT COUNT(*) FROM predictions WHERE predicted_digit = true_label;")
    
    # Display basic statistics
    echo "Total records: \${TOTAL_RECORDS} | Labeled records: \${LABELED_RECORDS} | Correct predictions: \${CORRECT_PREDICTIONS}"
    
    # Calculate and display accuracy
    if [ "\$LABELED_RECORDS" != "0" ]; then
        ACCURACY=\$(echo "scale=2; (\$CORRECT_PREDICTIONS / \$LABELED_RECORDS) * 100" | bc)
        echo "Overall accuracy: \${ACCURACY}%"
    fi
    
    # Display recent predictions
    echo -e "\nRecent predictions:"
    docker exec \${DB_CONTAINER} psql -U \${DB_USER} -d \${DB_NAME} -c "
        SELECT 
            id, timestamp, predicted_digit, true_label, confidence 
        FROM predictions 
        ORDER BY timestamp DESC 
        LIMIT \$LIMIT;"
    
    # Display digit statistics
    echo -e "\nPredictions by digit:"
    docker exec \${DB_CONTAINER} psql -U \${DB_USER} -d \${DB_NAME} -c "
        SELECT 
            predicted_digit, 
            COUNT(*) as count,
            (AVG(confidence) * 100)::numeric(10,2) as avg_confidence_pct
        FROM predictions 
        GROUP BY predicted_digit 
        ORDER BY predicted_digit;"
    
    # Display accuracy by digit if we have labeled data
    if [ "\$LABELED_RECORDS" -gt 0 ]; then
        echo -e "\nAccuracy by digit:"
        docker exec \${DB_CONTAINER} psql -U \${DB_USER} -d \${DB_NAME} -c "
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
EOF

# Check if SSH command succeeded
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Remote database query complete.${NC}"
else
    echo -e "${RED}Failed to connect to remote server or retrieve database records.${NC}"
    exit 1
fi 