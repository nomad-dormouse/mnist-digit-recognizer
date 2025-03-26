#!/bin/bash

# Configuration
BACKUP_DIR="/root/db_backups"
CONTAINER_NAME="mnist-digit-recognizer-db-1"
DB_NAME="mnist_db"
DB_USER="postgres"
RESTORE_FILE="${BACKUP_DIR}/latest_backup.sql"  # Default to latest backup

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if a specific backup file was provided
if [ $# -eq 1 ]; then
    RESTORE_FILE="$1"
fi

echo -e "${YELLOW}Starting database restore...${NC}"

# Check if the backup file exists
if [ ! -f "${RESTORE_FILE}" ]; then
    echo -e "${RED}Error: Backup file ${RESTORE_FILE} does not exist!${NC}"
    echo -e "${YELLOW}Available backups:${NC}"
    ls -lh ${BACKUP_DIR}/*.sql 2>/dev/null || echo -e "${RED}No backups found in ${BACKUP_DIR}/${NC}"
    exit 1
fi

# Check if the container is running
if ! docker ps | grep -q ${CONTAINER_NAME}; then
    echo -e "${RED}Error: Database container ${CONTAINER_NAME} is not running!${NC}"
    exit 1
fi

# Perform the restore
echo -e "${YELLOW}Restoring ${DB_NAME} from ${RESTORE_FILE}...${NC}"

# Drop and recreate the database
docker exec ${CONTAINER_NAME} psql -U ${DB_USER} -c "DROP DATABASE IF EXISTS ${DB_NAME};"
docker exec ${CONTAINER_NAME} psql -U ${DB_USER} -c "CREATE DATABASE ${DB_NAME};"

# Restore the data
cat "${RESTORE_FILE}" | docker exec -i ${CONTAINER_NAME} psql -U ${DB_USER} ${DB_NAME}

# Check if restore was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Database restore completed successfully!${NC}"
else
    echo -e "${RED}Database restore failed!${NC}"
    exit 1
fi 