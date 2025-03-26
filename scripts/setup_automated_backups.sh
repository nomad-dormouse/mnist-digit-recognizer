#!/bin/bash

# Configuration
BACKUP_SCRIPT="/root/mnist-digit-recognizer/backup_db.sh"
CRON_SCHEDULE="0 0 * * *"  # Daily at midnight

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting up automated database backups...${NC}"

# Ensure backup script exists and is executable
if [ ! -f "${BACKUP_SCRIPT}" ]; then
    echo -e "${RED}Error: Backup script not found at ${BACKUP_SCRIPT}${NC}"
    exit 1
fi

chmod +x "${BACKUP_SCRIPT}"

# Create a temporary file for the crontab
TEMP_CRON=$(mktemp)

# Get existing crontab
crontab -l > "${TEMP_CRON}" 2>/dev/null || echo "# MNIST Digit Recognizer Automated Backups" > "${TEMP_CRON}"

# Check if our backup job is already in the crontab
if grep -q "${BACKUP_SCRIPT}" "${TEMP_CRON}"; then
    echo -e "${YELLOW}Backup job already exists in crontab. Updating...${NC}"
    sed -i "/.*${BACKUP_SCRIPT//\//\\/}.*/d" "${TEMP_CRON}"
fi

# Add the backup job to the crontab
echo "# MNIST Database Backup - Daily at midnight" >> "${TEMP_CRON}"
echo "${CRON_SCHEDULE} ${BACKUP_SCRIPT} >> /root/db_backups/backup.log 2>&1" >> "${TEMP_CRON}"

# Install the new crontab
crontab "${TEMP_CRON}"
rm "${TEMP_CRON}"

echo -e "${GREEN}Automated backups have been set up!${NC}"
echo -e "${GREEN}The database will be backed up daily at midnight.${NC}"
echo -e "${GREEN}Backup logs will be saved to: /root/db_backups/backup.log${NC}"

# Display the current crontab
echo -e "\n${YELLOW}Current crontab:${NC}"
crontab -l 