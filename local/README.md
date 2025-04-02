# Local Development Documentation

This directory contains tools and configurations for local development of the MNIST Digit Recognizer application.

## Directory Structure

```
local/
├── run_locally.sh      # Main script for local development
├── Dockerfile.local    # Docker configuration for local development
├── docker-compose.local.override.yml # Docker Compose overrides for local development
├── .env.local          # Environment variables for local development
└── helpers/            # Helper scripts for local development
    ├── view_local_db.sh    # View local database statistics
    └── view_mnist_samples.py # Generate HTML with MNIST samples
```

## Development Process

The local development process consists of several steps:

1. **Environment Setup**
   - Loads environment variables from `.env` and `.env.local`
   - Checks prerequisites (Docker)
   - Prepares for local development

2. **Application Setup**
   - Configures Docker Compose services for local development
   - Builds images with development settings
   - Launches containers with hot reloading enabled

3. **Database Management**
   - Initializes PostgreSQL database locally
   - Creates required tables if they don't exist
   - Provides tools to view and analyze the database

4. **Development Tools**
   - Enables viewing of MNIST samples
   - Provides database analysis tools
   - Allows for easy testing of the application

## Usage

To run the application locally:

1. Ensure you have the necessary environment variables in `.env.local`:
   ```bash
   APP_PORT=8501
   DB_HOST=localhost
   DB_PORT=5432
   # ... other variables
   ```

2. Run the local development script:
   ```bash
   ./local/run_locally.sh
   ```

3. Access the application at http://localhost:8501

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

## Troubleshooting

Common issues and solutions:

1. **Database Connection Issues**
   - Check if PostgreSQL container is running: `docker ps | grep db`
   - Verify port mapping: ensure port 5432 is properly mapped
   - Check for conflicting PostgreSQL instances on your machine

2. **Application Startup Failures**
   - Check Docker logs: `docker logs mnist-digit-recognizer-web-local`
   - Verify environment variables in .env and .env.local
   - Ensure model file exists in model/saved_models/

3. **Docker Issues**
   - Try stopping all containers: `docker-compose down`
   - Check Docker Desktop status
   - Ensure Docker has enough resources allocated

## Development Tips

- The application uses hot reloading, so changes to Python files will be reflected automatically
- Database changes persist between container restarts
- Use the view_local_db.sh script to monitor prediction accuracy and model performance
- Test with various MNIST samples using the view_mnist_samples.py tool 