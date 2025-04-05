-- Create predictions table if it doesn't exist
CREATE TABLE IF NOT EXISTS predictions (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    predicted_digit INTEGER NOT NULL,
    true_label INTEGER,
    confidence FLOAT NOT NULL
);