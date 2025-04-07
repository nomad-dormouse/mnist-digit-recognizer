#!/bin/bash
# DATABASE VIEWER FOR MNIST DIGIT RECOGNISER

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Change to project root directory
cd "$PROJECT_ROOT"

# Load environment variables
if [[ -f ".env" ]]; then
    source ".env"
else
    echo -e "${RED}Error: .env file not found in project root${NC}"
    exit 1
fi

# Parse command line arguments for query limit
QUERY_LIMIT=${1:-10}

# Check if the container is running
check_container() {
    if docker ps --format '{{.Names}}' | grep -q "^${1}$"; then
        echo -e "${GREEN}✓ $1 is running${NC}"
        return 0
    else
        echo -e "${RED}✗ $1 is not running${NC}"
        return 1
    fi
}

if ! check_container ${DB_CONTAINER_NAME}; then
    echo -e "Start the application first by running: ${BOLD}./deploy.sh local up${NC}"
    exit 1
fi

# Function to execute SQL query and format output nicely
execute_query() {
    local sql_query="$1"
    local title="$2"
    
    echo -e "\n${BLUE}======= ${title} =======${NC}\n"
    
    docker exec -it ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "${sql_query}" | \
    awk -v blue="${BLUE}" -v green="${GREEN}" -v reset="${NC}" -v yellow="${YELLOW}" '
    NR==1 {print yellow $0 reset; next}
    NR==2 && $0 ~ /^-+/ {print $0; next}
    NR>=3 {print green $0 reset; next}
    {print blue $0 reset}'
}

# Display database information
echo -e "${BLUE}Connecting to MNIST database on ${DB_CONTAINER_NAME}...${NC}"

# Get the count of predictions
execute_query "SELECT COUNT(*) FROM predictions;" "Total Predictions Count"

# Get recent predictions
if [[ "${QUERY_LIMIT}" == "all" ]]; then
    execute_query "SELECT * FROM predictions ORDER BY timestamp DESC;" "All Predictions"
else
    execute_query "SELECT * FROM predictions ORDER BY timestamp DESC LIMIT ${QUERY_LIMIT};" "Recent Predictions (Limited to ${QUERY_LIMIT})"
fi

# Display summary stats
execute_query "
    SELECT 
        predicted_digit, 
        COUNT(*) AS count, 
        ROUND(AVG(confidence) * 100, 2) AS avg_confidence_pct
    FROM 
        predictions 
    GROUP BY 
        predicted_digit 
    ORDER BY 
        predicted_digit;" "Predictions by Digit"

# Correct vs Incorrect predictions (if true_label exists)
HAS_TRUE_LABEL=$(docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c "\d predictions" | grep -c "true_label")

if [[ $HAS_TRUE_LABEL -gt 0 ]]; then
    # Check if there are any non-null true_label values
    HAS_VALUES=$(docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c "SELECT COUNT(*) FROM predictions WHERE true_label IS NOT NULL" | xargs)
    
    if [[ $HAS_VALUES -gt 0 ]]; then
        execute_query "
            SELECT 
                CASE WHEN predicted_digit = true_label THEN 'Correct' ELSE 'Incorrect' END AS prediction_result,
                COUNT(*) AS count,
                ROUND((COUNT(*) * 100.0) / (SELECT COUNT(*) FROM predictions WHERE true_label IS NOT NULL), 2) AS percentage,
                ROUND(AVG(confidence) * 100, 2) AS avg_confidence_pct
            FROM 
                predictions 
            WHERE 
                true_label IS NOT NULL
            GROUP BY 
                prediction_result;" "Prediction Accuracy"
                
        # Confusion matrix (if we have enough data)
        PREDICTION_COUNT=$(docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c "SELECT COUNT(*) FROM predictions WHERE true_label IS NOT NULL" | xargs)
        
        if [[ $PREDICTION_COUNT -gt 20 ]]; then
            execute_query "
                SELECT 
                    true_label AS actual_digit,
                    predicted_digit,
                    COUNT(*) AS count
                FROM 
                    predictions 
                WHERE 
                    true_label IS NOT NULL
                GROUP BY 
                    true_label, predicted_digit
                ORDER BY 
                    true_label, predicted_digit;" "Simple Confusion Matrix"
        fi
    else
        echo -e "\n${YELLOW}No predictions with true labels found. Accuracy stats not available.${NC}"
    fi
fi

# Interactive mode
echo -e "\n${BLUE}======= Interactive Query Mode =======${NC}"
echo -e "${YELLOW}You can now run your own SQL queries against the database.${NC}"
echo -e "${YELLOW}Type 'exit' to quit.${NC}\n"

docker exec -it ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} 