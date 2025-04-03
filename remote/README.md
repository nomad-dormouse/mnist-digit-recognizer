# Deployment Documentation

This directory contains deployment scripts and configuration for the MNIST Digit Recognizer application.

## Directory Structure

```
remote/
├── deploy_remotely.sh                 # Main consolidated deployment script
├── docker-compose.remote.override.yml # Docker Compose overrides for production
└── README.md                          # This file
```

## Overview

The `remote/` directory contains files related to deploying the MNIST Digit Recognizer application to a remote server using Docker Compose.

The main components include:
- `deploy_remotely.sh`: A consolidated bash script that handles deployment, monitoring, and maintenance of the application on a remote server
- `docker-compose.remote.override.yml`: Docker Compose configuration overrides specific to remote deployment
- Loads environment variables from the consolidated `.env` file in the project root

## Deployment Process

The recommended remote deployment flow is:

1. Configure your deployment environment variables in `.env` file
2. Make sure you have SSH access to the remote server
3. From the project root, run the deployment script:
   ```bash
   ./remote/deploy_remotely.sh
   ```
4. Access the deployed application at http://your-server-ip:8501

## Script Commands

The `deploy_remotely.sh` script supports multiple commands:

- **Deploy** the application (default):
  ```bash
  ./remote/deploy_remotely.sh deploy
  ```

- View **logs** from the web application:
  ```bash
  ./remote/deploy_remotely.sh logs [number_of_lines]
  ```

- View **database** contents:
  ```bash
  ./remote/deploy_remotely.sh db [limit|all]
  ```

- Check application **status**:
  ```bash
  ./remote/deploy_remotely.sh status
  ```

- **Stop** all services:
  ```bash
  ./remote/deploy_remotely.sh stop
  ```

## Configuration

Environment variables are defined in the `.env` file at the project root. This file contains all necessary configuration for both local development and remote deployment environments.

Key deployment configurations include:
- Remote server SSH details (`REMOTE_USER`, `REMOTE_HOST`, `SSH_KEY`)
- Database connection details (`DB_HOST`, `DB_PORT`, etc.)
- Container and volume names
- Port mappings

## Troubleshooting

Common issues and solutions:

- **SSH Connection Issues**: Verify SSH key path and permissions
- **Docker not available**: Ensure Docker and Docker Compose are installed on the remote server
- **Container startup issues**: Check logs with `./remote/deploy_remotely.sh logs`
- **Configuration issues**: Verify environment variables in `.env` 