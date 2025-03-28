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

## Manual Setup

If you prefer to set up the environment manually:

### 1. Create a virtual environment

```bash
python -m venv venv
source venv/bin/activate  # On Windows: .\venv\Scripts\activate
```

### 2. Install dependencies

```bash
pip install -r ../requirements.txt
```

### 3. Set up environment variables

Create a `.env.local` file in this directory with:
```
DB_HOST=localhost
DB_PORT=5432
DB_NAME=mnist_db
DB_USER=postgres
DB_PASSWORD=postgres
```

Or use the existing `.env.local` file as a template.

### 4. Initialize the PostgreSQL database

```bash
psql -U postgres -c "CREATE DATABASE mnist_db;"
psql -U postgres -d mnist_db -f ../database/init.sql
```

### 5. Run the Streamlit app

```bash
streamlit run ../app/app.py
```

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