# Deployment Documentation

This directory contains deployment scripts and configuration for the MNIST Digit Recognizer application.

## Directory Structure

```
deployment/
├── deploy.sh      # Main deployment script
├── common.sh      # Common functions and variables
├── database.sh    # Database management functions
├── services.sh    # Service management functions
├── containers.sh  # Container management functions
└── environment.sh # Environment setup functions
```

## Deployment Process

The deployment process consists of several steps:

1. **Environment Setup**
   - Verifies SSH access to the remote server
   - Creates necessary directories
   - Sets up logging

2. **Application Deployment**
   - Clones/updates the repository on the remote server
   - Builds Docker images
   - Configures Docker Compose services

3. **Database Management**
   - Initializes PostgreSQL database
   - Creates required tables
   - Sets up backup routines
   - Configures health monitoring

4. **Service Configuration**
   - Sets up systemd services for automatic startup
   - Configures health checks
   - Manages container lifecycle

## Usage

To deploy the application:

1. Configure your deployment settings in `deploy.sh`:
   ```bash
   REMOTE_USER="root"
   REMOTE_HOST="your-server-ip"
   REMOTE_DIR="/root/mnist-digit-recognizer"
   SSH_KEY="/path/to/your/ssh/key"
   ```

2. Run the deployment script:
   ```bash
   ./deploy.sh
   ```

## Monitoring and Maintenance

- View application logs:
  ```bash
  ../helpers/check_web_logs.sh
  ```

- Check database status:
  ```bash
  ../helpers/view_db.sh
  ```

- Monitor deployment logs:
  ```bash
  ssh user@host "tail -f /var/log/mnist_deploy.log"
  ```

## Troubleshooting

Common issues and solutions:

1. **Database Connection Issues**
   - Check if PostgreSQL container is running
   - Verify network configuration
   - Ensure database initialization completed

2. **Application Startup Failures**
   - Check Docker logs for errors
   - Verify environment variables
   - Ensure model file exists

3. **Permission Issues**
   - Check file ownership and permissions
   - Verify SSH key access
   - Ensure Docker has necessary permissions

## Backup and Recovery

The deployment includes automatic database backups:
- Backups are stored in `/root/db_backups`
- Retention policy keeps last 7 backups
- Manual backup can be triggered via `database.sh`

To restore from backup:
```bash
./database.sh restore
``` 