# Deployment Documentation

This directory contains all deployment-related scripts and configuration for the MNIST Digit Recognizer application.

## Directory Structure

```
deployment/
├── deploy.sh        # Main deployment script
├── common.sh        # Common functions and variables
├── environment.sh   # Environment setup functions
├── database.sh      # Database management functions
├── containers.sh    # Container management functions
├── services.sh      # Systemd service management
└── .env            # Environment configuration
```

## Deployment Configuration

The deployment configuration is managed through environment variables defined in `.env`. This file contains all necessary settings for:

- Remote server configuration
- Database settings
- Docker configuration
- Application settings
- Backup configuration

### Required Environment Variables

The following environment variables must be set in `.env`:

```bash
# Remote Server Settings
REMOTE_USER          # SSH user for remote deployment
REMOTE_HOST          # Remote server hostname/IP
REMOTE_DIR           # Remote directory for deployment
SSH_KEY             # Path to SSH key for authentication

# Repository Settings
REPO_URL            # Git repository URL

# Database Settings
DB_NAME             # PostgreSQL database name
DB_USER             # Database user
DB_PASSWORD         # Database password
DB_PORT             # Database port
DB_VOLUME_NAME      # Docker volume name for database
BACKUP_DIR          # Directory for database backups
MAX_BACKUPS         # Maximum number of backup files to keep
DB_CHECK_INTERVAL   # Interval for database health checks

# Container Settings
WEB_CONTAINER_NAME  # Web container name
DB_CONTAINER_NAME   # Database container name
DOCKER_COMPOSE_FILE # Path to docker-compose file
```

## Deployment Process

1. **Initial Setup**
   ```bash
   cd deployment
   ./deploy.sh
   ```
   This will:
   - Set up the remote environment
   - Initialize the database
   - Configure systemd services
   - Start the application

2. **Automated Management**
   The deployment includes:
   - Automatic database health checks (configurable interval)
   - Automatic backup system
   - Container health monitoring
   - Self-healing capabilities

3. **Systemd Services**
   - `mnist-app.service`: Manages the main application containers
   - `mnist-db-check.service`: Performs database health checks
   - `mnist-db-check.timer`: Schedules regular database checks

## Monitoring and Maintenance

- Database health is automatically checked at boot and at configured intervals
- Backups are automatically managed with rotation
- Container health is monitored and containers are automatically restarted if needed
- All operations are logged for troubleshooting

## Troubleshooting

Common issues can be diagnosed by checking:
1. Systemd service status:
   ```bash
   systemctl status mnist-app
   systemctl status mnist-db-check.timer
   ```

2. Container logs:
   ```bash
   docker logs ${WEB_CONTAINER_NAME}
   docker logs ${DB_CONTAINER_NAME}
   ```

3. Application logs in the remote directory

## Security Notes

- Sensitive information should only be stored in the `.env` file
- The `.env` file should never be committed to version control
- SSH keys should have appropriate permissions (600)
- Database backups should be stored securely 