# Server

This directory contains scripts and configuration files for server deployment and management of the MNIST Digit Recognizer application.

## Structure

- **deploy.sh**: Script for deploying the application to a production server
- **check_web_logs.sh**: Tool to view logs from the web container on the remote server
- **view_db.sh**: Database viewer to display prediction records and statistics
- **.env**: Environment variables for configuration

## Usage

### Deployment

To deploy the application to a production server:

1. Update the configuration in `deploy.sh` with your server details:
   ```bash
   # Example configuration
   REMOTE_HOST="your-server-ip"
   SSH_KEY="~/.ssh/id_rsa"
   REPO_URL="https://github.com/your-username/mnist-digit-recognizer.git"
   ```

2. Run the deployment script:
   ```bash
   ./server/deploy.sh
   ```

### Monitoring

To check the logs from the web application container:
```bash
./server/check_web_logs.sh [number_of_lines]
```

Example:
```bash
./server/check_web_logs.sh 100  # Show the last 100 lines
```

### Database Management

To view prediction records and statistics from the database:
```bash
./server/view_db.sh [limit|all]
```

Examples:
```bash
./server/view_db.sh        # Default 20 records
./server/view_db.sh 50     # Show 50 records
./server/view_db.sh all    # Show all records
```

## Notes

- All scripts require SSH access to the server
- Make sure you have the necessary permissions to connect to the server and database
- The deployment script includes setting up Docker containers and initializing the database 