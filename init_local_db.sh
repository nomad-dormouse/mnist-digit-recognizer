#!/bin/bash

# Create the database if it doesn't exist
psql -U dormouse -c "CREATE DATABASE mnist_db;" 2>/dev/null || echo "Database mnist_db already exists"

# Create the predictions table if it doesn't exist
psql -U dormouse -d mnist_db -c "
CREATE TABLE IF NOT EXISTS predictions (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP NOT NULL,
    predicted_digit INTEGER NOT NULL,
    true_label INTEGER,
    confidence FLOAT NOT NULL
);"

echo "Database initialized successfully!" 