#!/bin/bash

# Default configuration
WEB_CONTAINER_NAME="digitrecogniserformlinstitute-web-1"
DB_CONTAINER_NAME="digitrecogniserformlinstitute-db-1" 
DB_NAME="mnist_db"
DB_USER="postgres"
DB_PASSWORD="postgres"
DB_HOST="localhost"
DB_PORT="5432"
LIMIT=20  # Default number of records to show
MODE="web-app"  # Default mode: web-app, local, or container

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display help
show_help() {
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  ./scripts/view_db.sh [options]"
    echo -e ""
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  -l, --local         View local database directly"
    echo -e "  -c, --container     View container database directly"
    echo -e "  -w, --web-app       View database as the web app would (default)"
    echo -e "  -n, --limit=NUMBER  Limit the number of records to show (default: 20)"
    echo -e "  -a, --all           Show all records"
    echo -e "  -h, --help          Show this help message"
    echo -e ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  ./scripts/view_db.sh                # View web app database (20 records)"
    echo -e "  ./scripts/view_db.sh -l             # View local database directly (20 records)"
    echo -e "  ./scripts/view_db.sh -c             # View container database directly (20 records)"
    echo -e "  ./scripts/view_db.sh -l -n 50       # View local database (50 records)"
    echo -e "  ./scripts/view_db.sh --all          # View all records in web app database"
    exit 0
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -l|--local) MODE="local" ;;
        -c|--container) MODE="container" ;;
        -w|--web-app) MODE="web-app" ;;
        -n|--limit) LIMIT="$2"; shift ;;
        --limit=*) LIMIT="${1#*=}" ;;
        -a|--all) LIMIT="ALL" ;;
        -h|--help) show_help ;;
        *) echo -e "${RED}Unknown parameter: $1${NC}"; show_help ;;
    esac
    shift
done

# Set mode-specific parameters
if [ "$MODE" = "local" ]; then
    # Local database settings
    DB_USER=$(whoami)  # Use current user for local PostgreSQL
    MODE_DESC="local"
    
    # Check if psql is available
    if ! command -v psql &> /dev/null; then
        echo -e "${RED}Error: PostgreSQL client (psql) is not installed or not in PATH!${NC}"
        exit 1
    fi
    
    # Define the query execution function for local mode
    execute_query() {
        psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c "$1"
    }
    
    # Define the value query function for local mode
    query_value() {
        psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -tAc "$1"
    }
    
    # Check if the database is accessible
    if ! psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c "SELECT 1" &> /dev/null; then
        echo -e "${RED}Error: Cannot connect to the local database! Check your PostgreSQL service.${NC}"
        echo -e "${RED}Try running 'psql -d ${DB_NAME}' manually to check the connection.${NC}"
        exit 1
    fi
elif [ "$MODE" = "container" ]; then
    # Direct container database mode
    MODE_DESC="container"
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker is not installed or not in PATH!${NC}"
        exit 1
    fi
    
    # Check if the db container is running
    if ! docker ps | grep -q ${DB_CONTAINER_NAME}; then
        echo -e "${RED}Error: Database container ${DB_CONTAINER_NAME} is not running!${NC}"
        exit 1
    fi
    
    # Define the query execution function for direct container mode
    execute_query() {
        docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "$1"
    }
    
    # Define the value query function for direct container mode
    query_value() {
        docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -tAc "$1"
    }
else
    # Web app database mode (mimics the web app's connection behavior)
    MODE_DESC="web app (simulated)"
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker is not installed or not in PATH!${NC}"
        echo -e "${RED}Falling back to local database.${NC}"
        MODE="local"
        MODE_DESC="local (web app fallback)"
        DB_USER=$(whoami)
        
        # Define the query execution function for local mode
        execute_query() {
            psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c "$1"
        }
        
        # Define the value query function for local mode
        query_value() {
            psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -tAc "$1"
        }
        
        # Check if the database is accessible
        if ! psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c "SELECT 1" &> /dev/null; then
            echo -e "${RED}Error: Cannot connect to the local database! Check your PostgreSQL service.${NC}"
            echo -e "${RED}Try running 'psql -d ${DB_NAME}' manually to check the connection.${NC}"
            exit 1
        fi
    else
        # Check if the web container is running
        if ! docker ps | grep -q ${WEB_CONTAINER_NAME}; then
            echo -e "${RED}Error: Web container ${WEB_CONTAINER_NAME} is not running!${NC}"
            echo -e "${RED}Falling back to local database.${NC}"
            MODE="local"
            MODE_DESC="local (web app fallback)"
            DB_USER=$(whoami)
            
            # Define the query execution function for local mode
            execute_query() {
                psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c "$1"
            }
            
            # Define the value query function for local mode
            query_value() {
                psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -tAc "$1"
            }
            
            # Check if the database is accessible
            if ! psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c "SELECT 1" &> /dev/null; then
                echo -e "${RED}Error: Cannot connect to the local database! Check your PostgreSQL service.${NC}"
                echo -e "${RED}Try running 'psql -d ${DB_NAME}' manually to check the connection.${NC}"
                exit 1
            fi
        else
            # Use the web container's connection pattern - mimic app.py connection logic
            # First try container DB, then fallback to local
            
            # Try container DB first
            if docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "SELECT 1" &> /dev/null; then
                MODE_DESC="container (web app connection)"
                # Define the query execution function for container mode via web app logic
                execute_query() {
                    docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "$1"
                }
                
                # Define the value query function for container mode via web app logic
                query_value() {
                    docker exec ${DB_CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -tAc "$1"
                }
            else
                # Fallback to local as the web app would
                echo -e "${YELLOW}Cannot connect to container database. Falling back to local database (as web app would).${NC}"
                MODE="local"
                MODE_DESC="local (web app fallback)"
                DB_USER=$(whoami)
                
                # Define the query execution function for local mode
                execute_query() {
                    psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c "$1"
                }
                
                # Define the value query function for local mode
                query_value() {
                    psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -tAc "$1"
                }
                
                # Check if the database is accessible
                if ! psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c "SELECT 1" &> /dev/null; then
                    echo -e "${RED}Error: Cannot connect to the local database! Check your PostgreSQL service.${NC}"
                    echo -e "${RED}Try running 'psql -d ${DB_NAME}' manually to check the connection.${NC}"
                    exit 1
                fi
            fi
        fi
    fi
fi

echo -e "${YELLOW}Viewing ${MODE_DESC} database content (limit: $LIMIT)...${NC}"

# Count total records
TOTAL_RECORDS=$(query_value "SELECT COUNT(*) FROM predictions;")
echo -e "${GREEN}Total records in database: ${TOTAL_RECORDS}${NC}"

# Count records with true labels
LABELED_RECORDS=$(query_value "SELECT COUNT(*) FROM predictions WHERE true_label IS NOT NULL;")
echo -e "${GREEN}Records with true labels: ${LABELED_RECORDS}${NC}"

# Count correct predictions
CORRECT_PREDICTIONS=$(query_value "SELECT COUNT(*) FROM predictions WHERE predicted_digit = true_label;")
echo -e "${GREEN}Correct predictions: ${CORRECT_PREDICTIONS}${NC}"

# Calculate accuracy
if [ "$LABELED_RECORDS" != "0" ]; then
    # Check if bc is available
    if command -v bc &> /dev/null; then
        ACCURACY=$(echo "scale=2; ($CORRECT_PREDICTIONS / $LABELED_RECORDS) * 100" | bc)
        echo -e "${BLUE}Overall accuracy: ${ACCURACY}%${NC}"
    else
        echo -e "${RED}Cannot calculate accuracy: 'bc' command not found${NC}"
    fi
else
    echo -e "${RED}Cannot calculate accuracy: No records with true labels found${NC}"
fi

# Execute query to get records
echo -e "\n${YELLOW}Recent predictions:${NC}"
echo -e "${GREEN}ID | TIMESTAMP | PREDICTED_DIGIT | TRUE_LABEL | CONFIDENCE${NC}"
echo -e "${GREEN}--------------------------------------------------${NC}"

execute_query "
    SELECT 
        id, 
        timestamp, 
        predicted_digit, 
        true_label, 
        confidence 
    FROM predictions 
    ORDER BY timestamp DESC 
    LIMIT $LIMIT;"

echo -e "\n${YELLOW}Statistics:${NC}"
echo -e "${GREEN}Predictions by digit:${NC}"
execute_query "
    SELECT 
        predicted_digit, 
        COUNT(*) as count,
        (AVG(confidence) * 100)::numeric(10,2) as avg_confidence_pct
    FROM predictions 
    GROUP BY predicted_digit 
    ORDER BY predicted_digit;"

# Calculate accuracy by digit
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
        (correct::float / total * 100)::numeric(10,2) as accuracy_pct,
        (SELECT AVG(confidence)::numeric(10,2) * 100 
         FROM predictions 
         WHERE true_label = stats.true_label 
           AND predicted_digit = true_label) as avg_confidence_correct
    FROM stats
    ORDER BY true_label;"

# Show confusion matrix if there are enough records
if [ "$LABELED_RECORDS" -gt 5 ]; then
    echo -e "\n${YELLOW}Confusion matrix (true labels vs predictions):${NC}"
    execute_query "
        WITH matrix AS (
            SELECT 
                true_label,
                predicted_digit,
                COUNT(*) as count
            FROM predictions
            WHERE true_label IS NOT NULL
            GROUP BY true_label, predicted_digit
        )
        SELECT 
            'True label: ' || true_label as true_label,
            json_object_agg(
                'Predicted as ' || predicted_digit, 
                count
            ) as predictions
        FROM matrix
        GROUP BY true_label
        ORDER BY true_label;"

    # Show most common misclassifications
    echo -e "\n${YELLOW}Top misclassifications:${NC}"
    execute_query "
        SELECT 
            true_label as actual_digit,
            predicted_digit as predicted_as,
            COUNT(*) as count,
            AVG(confidence)::numeric(10,2) * 100 as avg_confidence_pct
        FROM predictions
        WHERE true_label IS NOT NULL
          AND true_label != predicted_digit
        GROUP BY true_label, predicted_digit
        ORDER BY count DESC
        LIMIT 5;"
fi

echo -e "\n${GREEN}Usage Tips:${NC}"
echo -e "${GREEN}* View as web app would: ./scripts/view_db.sh [--limit=N|--all]${NC}"
echo -e "${GREEN}* View local database: ./scripts/view_db.sh --local [--limit=N|--all]${NC}"
echo -e "${GREEN}* View container database: ./scripts/view_db.sh --container [--limit=N|--all]${NC}"
echo -e "${GREEN}* For help: ./scripts/view_db.sh --help${NC}"

# Display connection mode in summary
echo -e "\n${YELLOW}Connection Summary:${NC}"
if [ "$MODE" = "local" ]; then
    echo -e "${GREEN}Connected to local database as user '${DB_USER}'${NC}"
elif [ "$MODE" = "container" ]; then
    echo -e "${GREEN}Connected directly to container database '${DB_CONTAINER_NAME}' as user '${DB_USER}'${NC}"
else
    # Web app mode
    if [[ "$MODE_DESC" == *"container"* ]]; then
        echo -e "${GREEN}Connected to container database using web app connection method${NC}"
        echo -e "${GREEN}Connection details: container=${DB_CONTAINER_NAME}, user=${DB_USER}, database=${DB_NAME}${NC}"
    else
        echo -e "${GREEN}Connected to local database using web app fallback connection${NC}"
        echo -e "${GREEN}Connection details: host=${DB_HOST}, user=${DB_USER}, database=${DB_NAME}${NC}"
    fi
fi

# Remote connection tip
echo -e "\n${YELLOW}Want to connect to the remote server?${NC}"
echo -e "${GREEN}ssh root@37.27.197.79 \"cd /root/mnist-digit-recognizer && ./view_db.sh\"${NC}" 