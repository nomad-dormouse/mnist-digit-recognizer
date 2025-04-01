#!/bin/bash

# ================================================================================
# WEB APPLICATION LOGS VIEWER
# ================================================================================
# This script shows the logs from the web container on the remote server
# 
# Usage:
#   ./server/check_web_logs.sh [number_of_lines]
#
# Example:
#   ./server/check_web_logs.sh 100     # Show the last 100 lines
# ================================================================================

# Configuration
REMOTE_USER="root"
REMOTE_HOST="37.27.197.79"
REMOTE_DIR="/root/mnist-digit-recognizer"
SSH_KEY="${HOME}/.ssh/hetzner_key"
LINES="${1:-50}"  # Default to 50 lines if not specified

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if SSH key exists
if [ ! -f "${SSH_KEY}" ]; then
    echo -e "${RED}Error: SSH key not found at ${SSH_KEY}${NC}"
    exit 1
fi

echo -e "${YELLOW}Connecting to ${REMOTE_HOST} to view web container logs...${NC}"

# SSH into the remote server and run the database viewer
ssh -i ${SSH_KEY} ${REMOTE_USER}@${REMOTE_HOST} << EOF
    cd ${REMOTE_DIR}
    
    # Find web container
    WEB_CONTAINER=\$(docker ps | grep 'mnist-digit-recognizer_web' | awk '{print \$1}')
    
    if [ -z "\${WEB_CONTAINER}" ]; then
        echo "Web container not found! Check if the containers are running."
        exit 1
    fi
    
    echo "Found web container: \${WEB_CONTAINER}"
    echo "Showing last ${LINES} lines of logs..."
    
    # Display logs
    docker logs \${WEB_CONTAINER} --tail ${LINES}
    
    # Show Docker network information
    echo -e "\nDocker network information:"
    docker network ls
    
    # Inspect the network
    NETWORK_ID=\$(docker network ls | grep mnist-network | awk '{print \$1}')
    if [ -n "\${NETWORK_ID}" ]; then
        echo -e "\nNetwork details for mnist-network:"
        docker network inspect \${NETWORK_ID}
    fi
    
    # Check database connection from web container
    echo -e "\nTesting database connection from web container:"
    docker exec \${WEB_CONTAINER} python -c "
import psycopg2
try:
    conn = psycopg2.connect(
        host='db',
        port=5432,
        dbname='mnist_db',
        user='postgres',
        password='postgres',
        connect_timeout=5
    )
    print('Connection successful!')
    conn.close()
except Exception as e:
    print(f'Connection failed: {e}')
"
EOF

echo -e "${GREEN}Log check complete.${NC}" 