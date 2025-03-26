#!/bin/bash

echo "===== MNIST Digit Recognizer - Local Setup ====="
echo "Setting up environment and database..."

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python -m venv venv
fi

# Activate the virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt

# Set up local database
echo "Setting up local database..."

# Check if PostgreSQL is installed
if ! command -v psql &> /dev/null; then
    echo "PostgreSQL is not installed. Please install PostgreSQL and try again."
    exit 1
fi

# Check if PostgreSQL server is running
if ! pg_isready &> /dev/null; then
    echo "PostgreSQL server is not running. Please start the PostgreSQL server and try again."
    exit 1
fi

# Database configuration
DB_NAME="mnist_db"
DB_USER="postgres"
DB_PASSWORD="postgres"
DB_HOST="localhost"
DB_PORT="5432"

# Create database if it doesn't exist
if ! psql -h $DB_HOST -p $DB_PORT -U $DB_USER -lqt | cut -d \| -f 1 | grep -qw $DB_NAME; then
    echo "Creating database $DB_NAME..."
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -c "CREATE DATABASE $DB_NAME;"
fi

# Create table if it doesn't exist
echo "Creating predictions table if it doesn't exist..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
CREATE TABLE IF NOT EXISTS predictions (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    predicted_digit INTEGER NOT NULL,
    true_label INTEGER,
    confidence FLOAT NOT NULL
);"

# Set environment variables for the application
export DB_HOST=$DB_HOST
export DB_PORT=$DB_PORT
export DB_NAME=$DB_NAME
export DB_USER=$DB_USER
export DB_PASSWORD=$DB_PASSWORD
export PYTHONPATH=$PWD

echo "===== Setup Complete! ====="
echo "Starting application..."

# Run the Streamlit app
streamlit run app/app.py 