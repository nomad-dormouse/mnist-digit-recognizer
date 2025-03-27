# Server Management Scripts

This directory contains scripts for managing the MNIST Digit Recognizer application deployment and server operations.

## Available Scripts

- **deploy.sh**: Deploys the application to the server, sets up the environment, and starts the containers. Includes removing the PostgreSQL volume for clean initialization.
- **server_setup.sh**: Initial server configuration script to install required dependencies and set up the environment.
- **view_db.sh**: Displays database statistics and prediction history on the remote server.

## Usage Examples

### Deploy the application:
```bash
./scripts/deploy.sh
```

### Initial server setup (run before first deployment):
```bash
./scripts/server_setup.sh
```

### View database statistics on the remote server:
```bash
# Connect to remote server and view database
ssh -i ~/.ssh/hatzner_key root@37.27.197.79 "cd /root/mnist-digit-recognizer && ./scripts/view_db.sh"

# View with custom record limit
ssh -i ~/.ssh/hatzner_key root@37.27.197.79 "cd /root/mnist-digit-recognizer && ./scripts/view_db.sh 50"

# View all records
ssh -i ~/.ssh/hatzner_key root@37.27.197.79 "cd /root/mnist-digit-recognizer && ./scripts/view_db.sh all"
```

## Local Development

For local development tools, please see the `local/` directory in the project root:

```bash
# Run the application locally
./local/run_locally.sh

# View local database
./local/view_local_db.sh
``` 