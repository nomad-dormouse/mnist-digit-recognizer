# Local Development Documentation

This directory contains tools and configurations for local development of the MNIST Digit Recognizer application.

## Directory Structure

```
local/
├── README.md                # This file
├── deploy_locally.sh        # Script to run the app locally
├── view_local_db.sh         # View local database records
├── view_mnist_samples.py    # View MNIST dataset samples
└── mnist_samples.html       # Pre-generated HTML with MNIST samples
```

## Overview

The `local/` directory contains files related to running the MNIST Digit Recognizer application in a local development environment using Docker Compose.

The main components include:
- `deploy_locally.sh`: A bash script that sets up and runs the application locally
- `view_local_db.sh`: A utility script to view and query the database
- `view_mnist_samples.py`: A tool to generate HTML with MNIST dataset samples
- `mnist_samples.html`: Pre-generated samples for reference

The local environment:
- Uses environment variables from the consolidated `.env` file in the project root
- Sets `IS_DEVELOPMENT=true` for development-specific behaviors
- Mounts the project directory for hot reloading during development

For deployment to a remote server, use the `deploy.sh` script in the project root directory.

## Development Process

The recommended local development flow is:

1. Ensure you have Docker Desktop running
2. Configure your environment variables in `.env` file
3. From the project root, run the local development script:
   ```bash
   ./local/deploy_locally.sh
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

The main environment difference is the `IS_DEVELOPMENT` flag:
- Set to `true` by default
- Set to `false` for remote deployment

## Usage

### Running Locally

1. Ensure Docker Desktop is running
2. From the project root directory, run:
   ```bash
   ./local/deploy_locally.sh
   ```
3. Access the application at http://localhost:8501

### Troubleshooting

- **Docker not running**: Ensure Docker Desktop is running
- **Port conflicts**: Check if port 8501 is already in use by another application
- **Configuration issues**: Verify environment variables in `.env`
- **Missing model**: The model file is included in the repository, but if missing, you'll need to train it

## Monitoring and Tools

- View local database contents:
  ```bash
  ./local/view_local_db.sh [limit|all]
  ```

- Generate HTML with MNIST samples (uses the consolidated data in model/data):
  ```bash
  python local/view_mnist_samples.py
  ```

- Monitor containers:
  ```bash
  docker ps
  docker logs mnist-digit-recognizer-web
  ```
## Development Tips

- The application uses hot reloading, so changes to Python files will be reflected automatically
- Database changes persist between container restarts thanks to Docker volumes
- Use the view_local_db.sh script to monitor prediction accuracy and model performance
- Test with various MNIST samples using the view_mnist_samples.py tool 
