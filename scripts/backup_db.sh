#!/bin/bash

# Configuration
BACKUP_DIR="/root/db_backups"
CONTAINER_NAME="mnist-digit-recognizer-db-1"
DB_NAME="mnist_db"
DB_USER="postgres"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/mnist_db_${TIMESTAMP}.sql"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create backup directory if it doesn't exist
mkdir -p ${BACKUP_DIR}

echo -e "${YELLOW}Starting database backup...${NC}"

# Check if the container is running
if ! docker ps | grep -q ${CONTAINER_NAME}; then
    echo -e "${RED}Error: Database container ${CONTAINER_NAME} is not running!${NC}"
    exit 1
fi

# Perform the backup
echo -e "${YELLOW}Backing up ${DB_NAME} to ${BACKUP_FILE}...${NC}"
docker exec ${CONTAINER_NAME} pg_dump -U ${DB_USER} ${DB_NAME} > ${BACKUP_FILE}

# Check if backup was successful
if [ -s "${BACKUP_FILE}" ]; then
    echo -e "${GREEN}Backup completed successfully!${NC}"
    echo -e "${GREEN}Backup saved to: ${BACKUP_FILE}${NC}"
    
    # Keep only the 10 most recent backups
    echo -e "${YELLOW}Cleaning up old backups...${NC}"
    ls -t ${BACKUP_DIR}/mnist_db_*.sql | tail -n +11 | xargs -r rm
    echo -e "${GREEN}Backup cleanup completed.${NC}"
else
    echo -e "${RED}Backup failed or created an empty file!${NC}"
    rm -f "${BACKUP_FILE}"
    exit 1
fi

# Create a symbolic link to the latest backup for easy access
ln -sf ${BACKUP_FILE} ${BACKUP_DIR}/latest_backup.sql
echo -e "${GREEN}Created symbolic link to latest backup at: ${BACKUP_DIR}/latest_backup.sql${NC}" 