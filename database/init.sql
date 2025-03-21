CREATE TABLE IF NOT EXISTS predictions (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP NOT NULL,
    predicted_digit INTEGER NOT NULL,
    true_label INTEGER,
    confidence FLOAT NOT NULL
); 