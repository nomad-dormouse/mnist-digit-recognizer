# Server Management Scripts

This directory contains scripts for managing the MNIST Digit Recognizer application deployment and server operations.

## Available Scripts

- **deploy.sh**: Deploys the application to the server, sets up the environment, and starts the containers.
- **server_setup.sh**: Initial server configuration script to install required dependencies and set up the environment.
- **backup_db.sh**: Creates a backup of the PostgreSQL database.
- **restore_db.sh**: Restores the PostgreSQL database from a backup.
- **safe_restart.sh**: Safely restarts the application with database backup and recovery.
- **setup_automated_backups.sh**: Sets up automated daily backups via cron jobs.

## Usage Examples

### Deploy the application:
```bash
./scripts/deploy.sh
```

### Backup the database:
```bash
./scripts/backup_db.sh
```

### Set up automated backups:
```bash
./scripts/setup_automated_backups.sh
```

### Safely restart the application:
```bash
./scripts/safe_restart.sh
```

### Initial server setup (run before first deployment):
```bash
./scripts/server_setup.sh
``` 