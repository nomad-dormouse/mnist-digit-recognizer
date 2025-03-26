#!/bin/bash

# Configuration
PROJECT_DIR="/root/mnist-digit-recognizer"
BACKUP_DIR="/root/db_backups"
DB_CONTAINER="mnist-digit-recognizer-db-1"
WEB_CONTAINER="mnist-digit-recognizer-web-1"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting safe restart process...${NC}"

# Check if backup scripts exist
if [ ! -f "scripts/backup_db.sh" ] || [ ! -f "scripts/restore_db.sh" ]; then
    echo -e "${RED}Error: Backup or restore scripts are missing!${NC}"
    exit 1
fi

# Make sure the scripts are executable
chmod +x scripts/backup_db.sh scripts/restore_db.sh

# Check if database container is running
if docker ps | grep -q ${DB_CONTAINER}; then
    # Step 1: Back up the database
    echo -e "${YELLOW}Step 1: Backing up the database...${NC}"
    scripts/backup_db.sh
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Database backup failed! Aborting restart.${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Database container not running. Skipping backup step.${NC}"
fi

# Step 2: Restart containers without removing volumes
echo -e "${YELLOW}Step 2: Restarting containers...${NC}"
cd ${PROJECT_DIR}
docker-compose down
docker-compose up -d

# Step 3: Wait for database to be ready
echo -e "${YELLOW}Step 3: Waiting for database to be ready...${NC}"
attempt=0
max_attempts=30
until docker exec ${DB_CONTAINER} pg_isready -U postgres &>/dev/null || [ $attempt -eq $max_attempts ]
do
    attempt=$((attempt+1))
    echo -e "${YELLOW}Waiting for database to start (attempt $attempt/$max_attempts)...${NC}"
    sleep 1
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "${RED}Database did not start in the allotted time!${NC}"
    exit 1
fi

# Step 4: Check if the database exists and has tables
echo -e "${YELLOW}Step 4: Checking database status...${NC}"
DB_EXISTS=$(docker exec ${DB_CONTAINER} psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='mnist_db'" | grep -c 1 || echo "0")

if [ "$DB_EXISTS" = "0" ]; then
    echo -e "${YELLOW}Database 'mnist_db' doesn't exist. Restoring from backup...${NC}"
    # Restore the database from backup
    scripts/restore_db.sh
else
    # Check if the predictions table exists
    TABLE_EXISTS=$(docker exec ${DB_CONTAINER} psql -U postgres -d mnist_db -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='predictions'" | grep -c 1 || echo "0")
    
    if [ "$TABLE_EXISTS" = "0" ]; then
        echo -e "${YELLOW}Table 'predictions' doesn't exist. Restoring from backup...${NC}"
        # Restore the database from backup
        scripts/restore_db.sh
    else
        echo -e "${GREEN}Database and tables exist. No restore needed.${NC}"
    fi
fi

# Step 5: Restart the web container to ensure it connects to the database
echo -e "${YELLOW}Step 5: Restarting web container...${NC}"
docker restart ${WEB_CONTAINER}

echo -e "${GREEN}Safe restart completed successfully!${NC}"
echo -e "${GREEN}The application should now be running at http://37.27.197.79:8501${NC}" 