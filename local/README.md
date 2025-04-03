# Local Development Documentation

This directory contains tools and configurations for local development of the MNIST Digit Recognizer application.

## Directory Structure

```
local/
├── docker-compose.local.override.yml  # Docker Compose overrides for local environment
├── README.md                          # This file
└── run_locally.sh                     # Script to run the app locally
```

## Overview

The `local/` directory contains files related to running the MNIST Digit Recognizer application in a local development environment using Docker Compose.

The main components include:
- `run_locally.sh`: A bash script that sets up and runs the application locally
- `docker-compose.local.override.yml`: Docker Compose configuration overrides specific to local development
- Loads environment variables from `.env`

## Development Process

The recommended local development flow is:

1. Ensure you have Docker Desktop running
2. Configure your environment variables in `.env` file
3. From the project root, run the local development script:
   ```bash
   ./local/run_locally.sh
   ```
4. Access the application at http://localhost:8501

## Configuration

Environment variables are defined in the `.env` file at the project root. This file contains all necessary configuration for both local development and remote deployment environments.

Key configurations include:
- Database connection details
- Model paths
- Container names
- Port mappings
- Paths for persisting data between runs

## Usage

### Running Locally

1. Ensure Docker Desktop is running
2. From the project root directory, run:
   ```bash
   ./local/run_locally.sh
   ```
3. Access the application at http://localhost:8501

### Troubleshooting

- **Docker not running**: Ensure Docker Desktop is running
- **Port conflicts**: Check if port 8501 is already in use by another application
- **Configuration issues**: Verify environment variables in `.env`

## Monitoring and Tools

- View local database contents:
  ```bash
  ./local/helpers/view_local_db.sh [limit|all]
  ```

- Generate HTML with MNIST samples:
  ```bash
  python local/helpers/view_mnist_samples.py
  ```

- Monitor containers:
  ```bash
  docker ps
  docker logs mnist-digit-recognizer-web-local
  ```

## Development Tips

- The application uses hot reloading, so changes to Python files will be reflected automatically
- Database changes persist between container restarts
- Use the view_local_db.sh script to monitor prediction accuracy and model performance
- Test with various MNIST samples using the view_mnist_samples.py tool 