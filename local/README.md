# Local Development

This directory contains tools and configurations for local development of the MNIST Digit Recognizer application.

## Quick Setup

The easiest way to run the application locally is with the provided script:

```bash
./run_locally.sh
```

This script will:
1. Start Docker containers for the app and database
2. Initialize the database with the proper schema
3. Configure all environment variables
4. Launch the application in Docker containers

## Available Tools

This directory includes several useful development tools:

- **run_locally.sh**: Main script for running the application in Docker
- **view_local_db.sh**: Script to view local database statistics and prediction history
- **view_mnist_samples.py**: Python script to generate an HTML file with MNIST dataset samples
- **Dockerfile.local**: Docker configuration for local development
- **.env.local**: Environment variable template for local development

## Viewing MNIST Samples

To view sample images from the MNIST dataset:

```bash
python view_mnist_samples.py
```

This will generate an HTML file with sample images from the dataset.

## Local Database Tools

To view the local database contents:

```bash
./view_local_db.sh
```

This will show statistics and prediction history from your local database.

## Local Docker Configuration

The `Dockerfile.local` contains the configuration for the local development Docker container. It's used by the `run_locally.sh` script to create a development environment that closely matches the production setup. 