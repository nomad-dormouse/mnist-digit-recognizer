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
├── Dockerfile.remote     # Production Dockerfile
├── docker-compose.remote.override.yml # Docker Compose overrides for production
├── README.md                          # This file
└── helpers/       # Helper scripts for monitoring and maintenance
    ├── check_web_logs.sh # View web application logs
    └── view_db.sh        # View database status
```

## Overview

The `remote/` directory contains files related to deploying the MNIST Digit Recognizer application to a remote server using Docker Compose.

The main components include:
- `deploy.sh`: A bash script that deploys the application to a remote server
- `docker-compose.remote.override.yml`: Docker Compose configuration overrides specific to remote deployment
- Loads environment variables from `.env`

## Deployment Process

The recommended remote deployment flow is:

1. Configure your deployment environment variables in `.env` file
2. Make sure you have SSH access to the remote server
3. From the project root, run the deployment script:
   ```bash
   ./remote/deploy.sh
   ```
4. Access the deployed application at http://your-server-ip:8501

## Configuration

Environment variables are defined in the `.env` file at the project root. This file contains all necessary configuration for both local development and remote deployment environments.

Key deployment configurations include:
- Remote server SSH details
- Database connection details
- Container and volume names
- Port mappings
- Backup settings

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

- **SSH Connection Issues**: Verify SSH key path and permissions
- **Docker not available**: Ensure Docker and Docker Compose are installed on the remote server
- **Container startup issues**: Check logs with `docker logs container-name`
- **Configuration issues**: Verify environment variables in `.env`

## Backup and Recovery

The deployment includes database backup functionality:
- Manual backup can be triggered via `database.sh`
- Ensure regular backups are configured

To restore from backup:
```bash
./remote/database.sh restore
``` 