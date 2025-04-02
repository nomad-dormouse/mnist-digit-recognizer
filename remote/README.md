# Deployment Documentation

This directory contains deployment scripts and configuration for the MNIST Digit Recognizer application.

## Directory Structure

```
remote/
├── deploy.sh      # Main deployment script
├── common.sh      # Common functions and variables
├── database.sh    # Database management functions
├── services.sh    # Service management functions
├── containers.sh  # Container management functions
├── environment.sh # Environment setup functions
├── Dockerfile     # Production Dockerfile
├── docker-compose.remote.override.yml # Docker Compose overrides for production
├── .env.remote    # Environment variables for remote deployment
└── helpers/       # Helper scripts for monitoring and maintenance
    ├── check_web_logs.sh # View web application logs
    └── view_db.sh        # View database status
```

## Deployment Process

The deployment process consists of several steps:

1. **Environment Setup**
   - Loads environment variables from `.env` and `.env.remote`
   - Checks prerequisites (Docker, model file)
   - Prepares for deployment

2. **Application Deployment**
   - Configures Docker Compose services
   - Builds images with production settings
   - Launches containers with resource constraints

3. **Database Management**
   - Initializes PostgreSQL database
   - Creates required tables if they don't exist
   - Ensures proper connections between services

4. **Health Checks**
   - Verifies that containers are running
   - Checks database connectivity
   - Ensures web application is accessible

## Usage

To deploy the application:

1. Configure your deployment settings in `.env.remote`:
   ```bash
   SSH_KEY="/path/to/your/ssh/key"
   REMOTE_HOST="your-server-ip"
   REMOTE_USER="root"
   REMOTE_DIR="/root/mnist-digit-recognizer"
   ```

2. Run the deployment script:
   ```bash
   ./remote/deploy.sh
   ```

## Monitoring and Maintenance

- View application logs:
  ```bash
  ./remote/helpers/check_web_logs.sh
  ```

- Check database status:
  ```bash
  ./remote/helpers/view_db.sh
  ```

- Monitor containers:
  ```bash
  docker ps
  docker logs mnist-digit-recognizer-web
  ```

## Troubleshooting

Common issues and solutions:

1. **Database Connection Issues**
   - Check if PostgreSQL container is running: `docker ps | grep db`
   - Verify network configuration in docker-compose files
   - Ensure database initialization completed: check logs

2. **Application Startup Failures**
   - Check Docker logs: `docker logs mnist-digit-recognizer-web`
   - Verify environment variables in .env and .env.remote
   - Ensure model file exists in model/saved_models/

3. **Permission Issues**
   - Check file ownership and permissions
   - Ensure Docker has necessary permissions

## Backup and Recovery

The deployment includes database backup functionality:
- Manual backup can be triggered via `database.sh`
- Ensure regular backups are configured

To restore from backup:
```bash
./remote/database.sh restore
``` 