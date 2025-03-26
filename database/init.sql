-- Create database if it doesn't exist
CREATE DATABASE mnist_db;

-- Connect to the database
\c mnist_db;

-- Create predictions table
DROP TABLE IF EXISTS predictions;
CREATE TABLE predictions (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    predicted_digit INTEGER NOT NULL,
    true_label INTEGER,
    confidence FLOAT NOT NULL
); 